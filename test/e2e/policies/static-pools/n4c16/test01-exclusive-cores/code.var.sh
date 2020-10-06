# VM topology tree with
# vm-files/etc/cmk/pools.conf sets visualized
# package  die  node  core  thread  cpu   pools.conf
# package0 die0 node0 core0 thread0 cpu00 exclusive-cpuLists[1]: 0,1
#                           thread1 cpu01 exclusive-cpuLists[1]: 0,1
#                     core1 thread0 cpu02 exclusive-cpuLists[2]: 2,3
#                           thread1 cpu03 exclusive-cpuLists[2]: 2,3
#               node1 core2 thread0 cpu04    shared-cpuLists[0]: 4,5,6,7
#                           thread1 cpu05    shared-cpuLists[0]: 4,5,6,7
#                     core3 thread0 cpu06    shared-cpuLists[0]: 4,5,6,7
#                           thread1 cpu07    shared-cpuLists[0]: 4,5,6,7
# package1 die0 node2 core0 thread0 cpu08 exclusive-cpuLists[0]: 8,9
#                           thread1 cpu09 exclusive-cpuLists[0]: 8,9
#                     core1 thread0 cpu10     infra-cpuLists[0]: 10,11,14,15
#                           thread1 cpu11     infra-cpuLists[0]: 10,11,14,15
#               node3 core2 thread0 cpu12     infra-cpuLists[1]: 12,13
#                           thread1 cpu13     infra-cpuLists[1]: 12,13
#                     core3 thread0 cpu14     infra-cpuLists[0]: 10,11,14,15
#                           thread1 cpu15     infra-cpuLists[0]: 10,11,14,15

cri_resmgr_cfg="$TEST_DIR/../cri-resmgr-static-pools.cfg"
static-pools-relaunch-cri-resmgr

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
