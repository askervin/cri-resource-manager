terminate cri-resmgr
launch cri-resmgr

verify-pod0-pod5-cpus() {
    verify 'len(cpus["pod0c0"]) == 1' \
           'len(cpus["pod0c1"]) == 1' \
           'len(cpus["pod0c2"]) == 1' \
           'len(cpus["pod0c3"]) == 1' \
           'len(cpus["pod1c0"]) >= 2' \
           'len(cpus["pod2c0"]) >= 3' \
           'len(cpus["pod3c0"]) >= 1' \
           'len(cpus["pod4c0"]) >= 1' \
           'disjoint_sets(cpus["pod0c0"], cpus["pod0c1"], cpus["pod0c2"], cpus["pod0c3"])' \
           'disjoint_sets(
                set.union(cpus["pod0c0"], cpus["pod0c1"], cpus["pod0c2"], cpus["pod0c3"]),
                set.union(cpus["pod1c0"], cpus["pod2c0"], cpus["pod3c0"], cpus["pod4c0"]))'


}

# Each of node0..node3 has shared CPU capacity of 4000m

# Pod0 containers take isolated CPU from every node
CPU=1 CONTCOUNT=4 create guaranteed # node0...4 free: 3000m

# Create shared pods: pod1, pod2, pod3 and pod4
CPUREQ=1300m CPULIM=1500m create burstable # node0 free: 1700m
verify 'nodes["pod1c0"] == {"node0"}'
CPUREQ=2200m CPULIM=2300m create burstable # node1 free: 800m
verify 'nodes["pod2c0"] == {"node1"}'
CPUREQ=300m CPULIM=400m create burstable # node2 free: 2700m
verify 'nodes["pod3c0"] == {"node2"}'
CPUREQ=500m CPULIM=2600m create burstable # node3 free: 2500m
verify 'nodes["pod4c0"] == {"node3"}'
report allowed

verify-pod0-pod5-cpus

# pod4 and pod5 (shared burstable pods)
# podNc0 should go to node2. node2 free shared: 600m
# podNc1 should go to node3. node3 free shared: 400m
# podNc2 should go to node0 + node1. package0 free shared: 400m
# Run twice: test releasing shared CPUs to shared CPU pool.
for podN in pod5 pod6; do
    CONTCOUNT=3 CPUREQ=2100m CPULIM=2200m create burstable
    report allowed
    verify "nodes['${podN}c0'] == {'node2'}" \
           "nodes['${podN}c1'] == {'node3'}" \
           "nodes['${podN}c2'] == {'node0', 'node1'}" \
           "len(cpus['${podN}c0']) >= 3" \
           "len(cpus['${podN}c1']) >= 3" \
           "len(cpus['${podN}c2']) >= 3"
    verify-pod0-pod5-cpus
    kubectl delete pods/${podN} --now
done

# pod6 and pod7 (guaranteed isolated pods)
# podNc0 should go to node2. node2 free shared: 2700m
# podNc1 should go to node3. node3 free shared: 2500m
# podNc2 should go to node0. node0 free shared: 1700m
# Run twice: test releasing isolated CPUs to shared CPU pool.
for podN in pod7 pod8; do
    CONTCOUNT=3 CPU=2 create guaranteed
    report allowed
    verify "disjoint_sets(cpus['${podN}c0'], cpus['${podN}c1'], cpus['${podN}c2'])" \
           "nodes['${podN}c0'] == nodes['pod3c0'] == {'node2'}" \
           "disjoint_sets(cpus['${podN}c0'], cpus['pod3c0'])" \
           "nodes['${podN}c1'] == nodes['pod4c0'] == {'node3'}" \
           "disjoint_sets(cpus['${podN}c1'], cpus['pod4c0'])" \
           "nodes['${podN}c2'] == nodes['pod1c0'] == {'node0'}" \
           "disjoint_sets(cpus['${podN}c2'], cpus['pod1c0'])" \
           "disjoint_sets(
               set.union(cpus['pod0c0'], cpus['pod0c1'], cpus['pod0c2'], cpus['pod0c3']),
               set.union(cpus['${podN}c0'], cpus['${podN}c1'], cpus['${podN}c2']))"
    verify-pod0-pod5-cpus
    kubectl delete pods/${podN} --now
done
