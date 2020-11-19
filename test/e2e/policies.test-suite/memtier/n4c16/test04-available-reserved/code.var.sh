# Test that AvailableResources are honored.

terminate cri-resmgr
cri_resmgr_cfg=$TEST_DIR/cri-resmgr-available-resources.cfg
launch cri-resmgr

# # Allocate exclusive CPUs
# CPU=3 create guaranteed
# verify "cpus['pod0c0'] == {'cpu04', 'cpu05', 'cpu06'}" \
#        "mems['pod0c0'] == {'node1'}"

# Allocate shared CPUs
CONTCOUNT=1 CPU=2500m create guaranteed
# verify "cpus['pod1c0'] == {'cpu08', 'cpu09', 'cpu10'}" \
#        "cpus['pod1c1'] == {'cpu08', 'cpu09', 'cpu10'}" \
#        "mems['pod1c0'] == {'node2'}" \
#        "mems['pod1c1'] == {'node2'}"
interactive
