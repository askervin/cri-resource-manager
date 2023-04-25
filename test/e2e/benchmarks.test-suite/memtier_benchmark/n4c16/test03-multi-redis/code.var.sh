# Redis parameters
REDIS_PASS=abc123xyz

redis_count=${redis_count:-4}
test_time_minutes=3
delay_between_rounds=30s
memtier_threads=2
test_time_seconds=$((test_time_minutes * 60))
test_timeout_minutes=$((test_time_minutes + 2))

# BM_* are benchmarks
BM_MEMTIER='memtier-benchmark --server=multiredis-service${REDIS_ID} --port=$(( 6379 + ${REDIS_ID} )) --authenticate=$REDIS_PASS --threads=${memtier_threads} --test-time=${test_time_seconds}'

# Clean up
vm-command 'set -x; kubectl delete deployments --all; kubectl delete jobs --all; kubectl delete services $(kubectl get services | awk "/multiredis-service/{print \$1}"); kubectl delete secret redis; kubectl delete pods --all --now; true'

vm-command "systemctl restart dbus"
vm-command "systemctl restart kubelet"

# Setup Redis
wait="" create redis-secret

for REDIS_ID in $(seq ${redis_count}); do
    REDIS_ID=${REDIS_ID} CPU=1 MEM=100M CPULIM=2 MEMLIM=512M NAME=redis${REDIS_ID} wait="Available" create multiredis
    REDIS_ID=${REDIS_ID} NAME=multiredis-service${REDIS_ID} wait="" create multiredis-service
done

# Reset counters in order to keep creating pod0...
reset counters

benchmark_output_dir="$OUTPUT_DIR/benchmark/multiredis"
mkdir -p "$benchmark_output_dir"

export NAME=memtier-benchmark
for bm_cmd in "${!BM_@}"; do
    for CPU in 1; do
        # Run benchmark
        for REDIS_ID in $(seq ${redis_count}); do
            wait="" REDIS_ID=${REDIS_ID} AFFINITY=affinity CPU="$CPU" MEM="128M" CPULIM="$CPU" MEMLIM="512M" ARGS="$(eval echo ${!bm_cmd#memtier-benchmark })" create multiredis-memtier-benchmark
        done
        for REDIS_ID in $(seq ${redis_count}); do
            kubectl wait --timeout=${test_timeout_minutes}m --for=condition=Completed Job/memtier-benchmark${REDIS_ID}
            memtier_benchmark_pod="$(kubectl get pods | awk '/memtier-benchmark${REDIS_ID}-/{print $1}')"
	    outfile="$benchmark_output_dir/$bm_cmd-redis-${REDIS_ID}of${redis_count}-cpu-$CPU-contcount-$CONTCOUNT.txt"
	    rm -f $outfile
	    contname=${NAME}${REDIS_ID}
	    echo "memtier benchmark CPU=$CPU log for $contname:"
	    kubectl logs "$memtier_benchmark_pod" "$contname" | grep -A7 'ALL STATS' | tee -a $outfile
        done
        kubectl delete jobs --all --now
	# find average from all containers:
	#============================================================================================================================
	#Type         Ops/sec     Hits/sec   Misses/sec    Avg. Latency     p50 Latency     p99 Latency   p99.9 Latency       KB/sec
	#----------------------------------------------------------------------------------------------------------------------------
	# sum_ops_sec=$(awk '/Totals/ {sum+=$2} END {print sum}' $outfile)
	# avg_ops_sec=$(awk '/Totals/ {sum+=$2;cnt++} END {printf("%d", sum/cnt)}' $outfile)
	# avg_latency=$(awk '/Totals/ {sum+=$5;cnt++} END {printf("%f", sum/cnt)}' $outfile)
	# avg_p50_lat=$(awk '/Totals/ {sum+=$6;cnt++} END {printf("%f", sum/cnt)}' $outfile)
	# avg_p99_lat=$(awk '/Totals/ {sum+=$7;cnt++} END {printf("%f", sum/cnt)}' $outfile)
	# printf "CPU=%2d CONTAINERS=%2d Ops/sec_sum:%7.0f Ops/sec_avg:%7.0f Latency:%f p50Latency:%f p99Latency:%f\n" \
	    #        $CPU $CONTCOUNT $sum_ops_sec $avg_ops_sec $avg_latency $avg_p50_lat $avg_p99_lat |tee -a $outfile
	# echo "sleep ${delay_between_rounds} between tests..."
	# echo "=================================================="
	sleep ${delay_between_rounds}
    done
done
