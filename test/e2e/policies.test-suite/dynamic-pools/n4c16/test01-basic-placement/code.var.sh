### Overview
#
# This script is executed in bash on the host. The bash context
# contains many e2e test framework functions for convenience.
#
# You can get an overview of these functions with:
#
# test/e2e/run.sh help script
#
# And you can get more detailed documentation of each function by
# adding the name of the function. For instance, see the "create"
# function documentation with:
#
# test/e2e/run.sh help script create
#
# If you need the source code of the functions, see in
# - test/e2e/run.sh
# - demo/lib/vm.bash
# - demo/lib/distro.bash
# - demo/lib/host.bash

### How to run this test?
#
# You can run this test script in test/e2e:
#
# ./run_tests.sh policies.test-suite/dynamic-pools/n4c16/test01-basic-placement
#
# If you wish to run all dynamic-pools tests in Debian sid, use:
#
# distro=debian-sid ./run_tests.sh policies.test-suite/dynamic-pools
#
# If you make changes to the dynamic pools policy then you can build
# cri-resmgr and re-run all dynamic-pools e2e tests with:
#
# make STATIC=1 DEBUG=1
# cd test/e2e
# ./run_tests.sh policies.test-suite/dynamic-pools

### The test logic
#
# Create a busybox pod with the create function. The "dyp-busybox"
# parameter will create it from "dyp-busybox.yaml.in" that can be
# found either in this directory or the first parent of it.
#
# The create function will automatically name the first pod as
# pod0.
#
# We do not add annotations to this pod, and we do not set any
# namespace, so this pod is expected to be created to the shared
# pool.
#
# Tip:
#
# The .yaml.in file will be instantiated using eval and echo in Bash.
# If you wish to make changes to the template or try evaluating it
# with different environment variables, you can try this without
# running a test as follows:
#
# NAME=pod0 eval "echo -e \"$(< dyp-busybox.yaml.in)\"" | grep -v '^ *$'
# NAME=podNN CPUREQ=500m CPULIM=1 eval "echo -e \"$(< dyp-busybox.yaml.in)\"" | grep -v '^ *$'
create dyp-busybox

# Output of the "report" function is helpful for debugging. It
# illustrates hardware topology and shows CPUs and memories that
# running pods are allowed to use.
report allowed

# Tip: if you wish to stop test script execution at some line and get
# an interactive prompt where you can test commands by directly typing
# them to the prompt, just use the "interactive" function.

# The "verify" function helps verifying properties of CPU pinning of
# pods. By default a failed verification stops the test script
# execution. Verification is given Python expressions that must
# evaluate to True. For example, verify that pod0 is allowed to use
# all available CPUs that are not reserved in the cri-resmgr
# configuration that is used in this test (which is here the default:
# test/e2e/policies.test-suite/dynamic-pools/cri-resmgr.cfg).
verify 'len(cpus["pod0c0"]) == 14'

# Let's create now a pod with two containers where both are annotated
# to be assigned to the same dynamic-pool: "pool1". The create
# function will name this pod automatically as "pod1" because "pod0"
# has been already created in this test. Furthermore, require that
# both containers in this pod get at least 3 CPUs.
CPUREQ=3 CPULIM=4 CONTCOUNT=2 POD_ANNOTATION="dynamic-pool.dynamic-pools.cri-resource-manager.intel.com/pod: pool1" create dyp-busybox

# Print allowed CPUs of pod0, that has only one container pod0c0, and
# pod1, that has two containers: pod1c0 and pod1c1. This way we can
# see the pinning directly from the output in case verification fails.
report allowed

# Verify that
# 1. containers of pod0 and pod1 cannot use same CPUs
# 2. pod1c0 and pod2c0 can use exactly the same CPUs, that is,
#    they belong to the same dynamic pool.
# 3. Because pod1c0 and pod1c1 share the same pool and both request
#    3 CPUs, they should be able allowed to use at least 6 CPUs in total.
verify 'disjoint_sets(cpus["pod0c0"], cpus["pod1c0"])' \
       'cpus["pod1c0"] == cpus["pod1c1"]' \
       'len(cpus["pod1c0"]) >= 6'

# TODO: add more tests on how the dynamic-pools policy should assign
# pods and containers when the rebalance loop is not being run.

# See test02-rebalancing/code.var.sh to learn about testing the
# rebalancing loop.
