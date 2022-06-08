# This test verifies that configuration updates via cri-resmgr-agent
# are handled properly in the balloons policy.

testns=e2e-balloons-test06

cleanup() {
    kubectl delete pods --all --now
    ( kubectl delete namespace $testns )
    ( kubectl delete btype1ns0 )
    terminate cri-resmgr
    terminate cri-resmgr-agent
    vm-command "cri-resmgr -reset-policy; cri-resmgr -reset-config"
}

apply-configmap() {
    vm-put-file $(instantiate balloons-configmap.yaml) balloons-configmap.yaml
    vm-command "cat balloons-configmap.yaml"
    kubectl apply -f balloons-configmap.yaml
}

cleanup
cri_resmgr_extra_args="-metrics-interval 1s" cri_resmgr_config=fallback launch cri-resmgr
launch cri-resmgr-agent

kubectl create namespace $testns
kubectl create namespace btype1ns0

AVAILABLE_CPU="cpuset:0,4-15" BTYPE2_NAMESPACE0='"*"' apply-configmap
sleep 3

# pod0 in btype0, annotation
CPUREQ=1 MEMREQ="100M" CPULIM=1 MEMLIM="100M"
POD_ANNOTATION="balloon.balloons.cri-resource-manager.intel.com: btype0" create balloons-busybox
# pod1 in btype1, namespace
CPUREQ=1 MEMREQ="100M" CPULIM=1 MEMLIM="100M"
namespace="btype1ns0" create balloons-busybox
# pod2 in btype2, wildcard namespace
CPUREQ=1 MEMREQ="100M" CPULIM=1 MEMLIM="100M"
namespace="e2e-balloons-test06" create balloons-busybox
vm-command "curl -s $verify_metrics_url"
interactive

BTYPE0_SKIP=1 BTYPE1_SKIP=1 BTYPE2_NAMESPACE0='"*"' apply-configmap
sleep 2
vm-command "curl -s $verify_metrics_url"
interactive

BTYPE0_SKIP=1 BTYPE1_SKIP=1 BTYPE2_NAMESPACE0='"*"' apply-configmap
sleep 2
vm-command "curl -s $verify_metrics_url"
