# Re-launch cri-resmgr with the rebalancing parameter in order to
# enable rebalancing calls. (See help of the "launch" function for
# more options.)
terminate cri-resmgr
cri_resmgr_extra_args="-rebalance-interval 2s -metrics-interval 2s" launch cri-resmgr

# Create three pods:
# - pod0 to "shared"
# - pod1 to "pool1"
# - pod2 to "pool2"
create dyp-busybox
POD_ANNOTATION="dynamic-pool.dynamic-pools.cri-resource-manager.intel.com/pod: pool1"
create dyp-busybox
POD_ANNOTATION="dynamic-pool.dynamic-pools.cri-resource-manager.intel.com/pod: pool2"
create dyp-busybox
# Print initial CPU pinning.
report allowed
# Wait at least one rebalancing round.
sleep 3

# Increase CPU usage of pod1 to 200%
vm-command "nohup kubectl exec pod1 -- /bin/sh -c 'gzip </dev/zero >/dev/null' </dev/null >&/dev/null &"
vm-command "nohup kubectl exec pod1 -- /bin/sh -c 'gzip </dev/zero >/dev/null' </dev/null >&/dev/null &"
# Wait at least one rebalancing round and print CPU pinning.
sleep 3
report allowed

# Now "pool1" has 200% CPU load, "shared" and "pool2" have 0%.
# Verify that pod in pool1 is allowed to use 12 out of 14 available CPUs.
verify 'len(cpus["pod1c0"]) == 12'

# Remove CPU load from pool1 and put 100% CPU load to pool2.
vm-command "pkill gzip"
vm-command "nohup kubectl exec pod2 -- /bin/sh -c 'gzip </dev/zero >/dev/null' </dev/null >&/dev/null &"
# Wait at least one rebalancing round and print CPU pinning.
sleep 3
report allowed

# Verify that the pod in pool2 is allowed to use 12 out of 14 available CPUs.
verify 'len(cpus["pod2c0"]) == 12'

# Tip: if you wish to get the number of CPUs in each pool you can use
# the "pp" function. It pretty-prints value of a Python expression. Example:
#
#   shared_cpucount=$(pp 'len(cpus["pod0c0"])')
#   pool1_cpucount=$(pp 'len(cpus["pod1c0"])')
#   pool2_cpucount=$(pp 'len(cpus["pod2c0"])')

# Tip: you can test that the metrics are updated and reported
# correctly by running
#   vm-command "curl --silent http://localhost:8891/metric"
#   grep EXPECTED <<< $COMMAND_OUTPUT
#
# For reference, see
# - policies.test-suite/balloons/n4c16/test02-prometheus-metrics/code.var.sh
# - policies.test-suite/balloons/verify.source.sh
