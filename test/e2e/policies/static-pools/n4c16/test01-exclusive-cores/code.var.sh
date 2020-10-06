# shellcheck disable=SC2148
cri_resmgr_cfg="$TEST_DIR/../cri-resmgr-static-pools.cfg" static-pools-relaunch-cri-resmgr

out ""
out "### Creating exclusive CMK pod with 1 exclusive core"
CPU=1000m SOCKET=1 EXCLCORES=1 create cmk-exclusive
report allowed
verify 'len(cores["pod0c0"]) == 1' \
       'packages["pod0c0"] == {"package1"}'

out ""
out "### Deleting exclusive CMK pod"
kubectl delete pods --all --now

out ""
out "### Creating exclusive CMK pod with 2 exclusive cores"
CPU=1000m SOCKET=0 EXCLCORES=2 create cmk-exclusive
report allowed
verify 'len(cores["pod1c0"]) == 2' \
       'packages["pod1c0"] == {"package0"}'

out ""
out "### Deleting exclusive CMK pod"
kubectl delete pods --all --now

out ""
out "### Creating two exclusive CMK pods with 1 exclusive core each"
n=2 CPU=1000m SOCKET=0 EXCLCORES=1 create cmk-exclusive
report allowed
verify 'len(cores["pod2c0"]) == 1' \
       'len(cores["pod3c0"]) == 1' \
       'disjoint_sets(cores["pod2c0"], cores["pod3c0"])' \
       'packages["pod2c0"] == packages["pod3c0"] == {"package0"}'

out ""
out "### Creating one more exclusive CMK pods, consuming all exclusive cores"
CPU=1000m SOCKET=1 EXCLCORES=1 create cmk-exclusive
report allowed
verify 'len(cores["pod2c0"]) == 1' \
       'len(cores["pod3c0"]) == 1' \
       'len(cores["pod4c0"]) == 1' \
       'disjoint_sets(cores["pod2c0"], cores["pod3c0"], cores["pod4c0"])' \
       'set.union(cores["pod2c0"], cores["pod3c0"], cores["pod4c0"]) == exclusive_cores'
