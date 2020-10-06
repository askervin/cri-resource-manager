static-pools-relaunch-cri-resmgr() {
    out "# Relaunching cri-resmgr, agent and webhook"

    # cleanup
    vm-command-q "kubectl get mutatingwebhookconfiguration/cri-resmgr" >/dev/null 2>&1 &&
        terminate cri-resmgr-webhook
    terminate cri-resmgr
    terminate cri-resmgr-agent
    extended-resources remove cmk.intel.com/exclusive-cpus >/dev/null

    # launch again
    launch cri-resmgr-agent
    launch cri-resmgr
    vm-wait-until "! kubectl get node | grep NotReady" ||
        error "kubectl node is NotReady after launching cri-resmgr-agent and cri-resmgr"
    vm-command-q "[ -f webhook/webhook-deployment.yaml ]" ||
        install cri-resmgr-webhook
    launch cri-resmgr-webhook
}
