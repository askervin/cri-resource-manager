#!/bin/bash

runs=${1:-10}
steps=${2:-10000}
pool_count=${pool_count:-}

if [ -n "$pool_count" ]; then
    pool_count_arg="-c pool_count=$pool_count"
else
    pool_count_arg=""
fi

# skip analyzis of pod-count-based pools: FillFirstFree FillBalanced FillPacked
for fillorder in FillMinCPU FillMaxCPU FillMaxPods; do
    echo "Simulating $runs x $steps steps of $fillorder, see walk.$fillorder.*.steps"
    cat <<EOF > "walk.$fillorder.conf"
model = aal_remote(remote_py3aal $pool_count_arg fillorder.aal -D delete -D $fillorder)
heuristic = random
coverage = 0
pass = steps($steps)
EOF
    for run in $(seq 1 "$runs"); do
        fmbt "walk.$fillorder.conf" 2>/dev/null | fmbt3-log -f "\$sn: [\$tb] \$as!" > "walk.$fillorder.$run.steps"
        pod_a="$(grep -c -E "fail to run pod=A.*create pod=A" "walk.$fillorder.$run.steps")"
        pod_b="$(grep -c -E "fail to run pod=B.*create pod=B" "walk.$fillorder.$run.steps")"
        pod_c="$(grep -c -E "fail to run pod=C.*create pod=C" "walk.$fillorder.$run.steps")"
        echo "$fillorder: fail A: $pod_a B: $pod_b C: $pod_c"
    done
done
