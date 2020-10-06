source "$(dirname "${BASH_SOURCE[0]}")/command.bash"
source "$(dirname "${BASH_SOURCE[0]}")/distro.bash"

VM_PROMPT=${VM_PROMPT-"\e[38;5;11mroot@vm>\e[0m "}

vm-compose-govm-template() {
    (echo "
vms:
  - name: ${VM_NAME}
    image: ${VM_IMAGE}
    cloud: true
    ContainerEnvVars:
      - KVM_CPU_OPTS=${VM_QEMU_CPUMEM:=-machine pc -smp cpus=4 -m 8G}
      - EXTRA_QEMU_OPTS=-monitor unix:/data/monitor,server,nowait ${VM_QEMU_EXTRA}
      - USE_NET_BRIDGES=${USE_NET_BRIDGES:-0}
    user-data: |
      #!/bin/bash
      set -e
"
    (if [ -n "$VM_EXTRA_BOOTSTRAP_COMMANDS" ]; then
         sed 's/^/      /g' <<< "${VM_EXTRA_BOOTSTRAP_COMMANDS}"
     fi
     sed 's/^/      /g' <<< $(distro-bootstrap-commands))) |
        grep -E -v '^ *$'
}

vm-image-url() {
    distro-image-url
}

vm-ssh-user() {
    distro-ssh-user
}

vm-check-env() {
    type -p govm >& /dev/null || {
        echo "ERROR:"
        echo "ERROR: environment check failed:"
        echo "ERROR:   govm binary not found."
        echo "ERROR:"
        echo "ERROR: You can install it using the following commands:"
        echo "ERROR:"
        echo "ERROR:     git clone https://github.com/govm-project/govm"
        echo "ERROR:     cd govm"
        echo "ERROR:     go build -o govm"
        echo "ERROR:     cp -v govm \$GOPATH/bin"
        echo "ERROR:     docker build . -t govm/govm:latest"
        echo "ERROR:     cd .."
        echo "ERROR:"
        return 1
    }
    docker inspect govm/govm >& /dev/null || {
        echo "ERROR:"
        echo "ERROR: environment check failed:"
        echo "ERROR:   govm/govm docker image not present (but govm needs it)."
        echo "ERROR:"
        echo "ERROR: You can install it using the following commands:"
        echo "ERROR:"
        echo "ERROR:     git clone https://github.com/govm-project/govm"
        echo "ERROR:     cd govm"
        echo "ERROR:     docker build . -t govm/govm:latest"
        echo "ERROR:     cd .."
        echo "ERROR:"
        return 1
    }
    if [ ! -e ${HOME}/.ssh/id_rsa.pub ]; then
        echo "ERROR:"
        echo "ERROR: environment check failed:"
        echo "ERROR:   id_rsa.pub SSH public key not found (but govm needs it)."
        echo "ERROR:"
        echo "ERROR: You can generate it using the following command:"
        echo "ERROR:"
        echo "ERROR:     ssh-keygen"
        echo "ERROR:"
        return 1
    fi
}

vm-check-binary-cri-resmgr() {
    # Check running cri-resmgr version, print warning if it is not
    # the latest local build.
    if [ -f "$BIN_DIR/cri-resmgr" ] && [ "$(vm-command-q 'md5sum < /proc/$(pidof cri-resmgr)/exe')" != "$(md5sum < "$BIN_DIR/cri-resmgr")" ]; then
        echo "WARNING:"
        echo "WARNING: Running cri-resmgr binary is different from"
        echo "WARNING: $BIN_DIR/cri-resmgr"
        echo "WARNING: Consider restarting with \"reinstall_cri_resmgr=1\" or"
        echo "WARNING: run.sh> uninstall cri-resmgr; install cri-resmgr; launch cri-resmgr"
        echo "WARNING:"
        sleep ${warning_delay}
        return 1
    fi
    return 0
}

vm-command() { # script API
    # Usage: vm-command COMMAND
    #
    # Execute COMMAND on virtual machine as root.
    # Returns the exit status of the execution.
    # Environment variable COMMAND_OUTPUT contains what COMMAND printed
    # in standard output and error.
    #
    # Examples:
    #   vm-command "kubectl get pods"
    #   vm-command "whoami | grep myuser" || command-error "user is not myuser"
    command-start "vm" "$VM_PROMPT" "$1"
    if [ "$2" == "bg" ]; then
        ( $SSH ${VM_SSH_USER}@${VM_IP} sudo bash -l <<<"$COMMAND" 2>&1 | command-handle-output ;
          command-end ${PIPESTATUS[0]}
        ) &
        command-runs-in-bg
    else
        $SSH ${VM_SSH_USER}@${VM_IP} sudo bash -l <<<"$COMMAND" 2>&1 | command-handle-output ;
        command-end ${PIPESTATUS[0]}
    fi
    return $COMMAND_STATUS
}

vm-command-q() {
    $SSH ${VM_SSH_USER}@${VM_IP} sudo bash -l <<<"$1"
}

vm-wait-process() { # script API
    # Usage: vm-wait-process [--timeout TIMEOUT] PROCESS
    #
    # Wait for a PROCESS (string) to appear in process list (ps -A output).
    # The default TIMEOUT is 30 seconds.
    local process timeout invalid
    timeout=30
    while [ "${1#-}" != "$1" -a -n "$1" ]; do
        case "$1" in
            --timeout)
                timeout="$2"
                shift; shift
                ;;
            *)
                invalid="${invalid}${invalid:+,}\"$1\""
                shift
                ;;
        esac
    done
    if [ -n "$invalid" ]; then
        error "invalid options: $invalid"
        return 1
    fi
    process="$1"
    vm-wait-until --timeout $timeout "ps -A | grep -q \"$process\""
}

vm-wait-until() { # script API
    # Usage: vm-wait-until [--timeout TIMEOUT] CMD
    #
    # Keep running CMD (string) until it exits successfully.
    # The default TIMEOUT is 30 seconds.
    local cmd timeout invalid
    timeout=30
    while [ "${1#-}" != "$1" -a -n "$1" ]; do
        case "$1" in
            --timeout)
                timeout="$2"
                shift; shift
                ;;
            *)
                invalid="${invalid}${invalid:+,}\"$1\""
                shift
                ;;
        esac
    done
    if [ -n "$invalid" ]; then
        error "invalid options: $invalid"
        return 1
    fi
    cmd="$1"
    if ! vm-command-q "retry=$timeout; until $cmd; do retry=\$(( \$retry - 1 )); [ \"\$retry\" == \"0\" ] && exit 1; sleep 1; done"; then
        error "waiting for command \"$cmd\" to exit successfully timed out after $timeout s"
    fi
}

vm-write-file() {
    local vm_path_file="$1"
    local file_content_b64="$(base64 <<<$2)"
    vm-command-q "mkdir -p $(dirname "$vm_path_file"); echo -n \"$file_content_b64\" | base64 -d > \"$vm_path_file\""
}

vm-put-file() { # script API
    # Usage: vm-put-file [--cleanup] [--append] SRC-HOST-FILE DST-VM-FILE
    #
    # Copy SRC-HOST-FILE to DST-VM-FILE on the VM, removing
    # SRC-HOST-FILE if called with the --cleanup flag, and
    # appending instead of copying if the --append flag is
    # specified.
    #
    # Example:
    #   src=$(mktemp) && \
    #       echo 'Ahoy, Matey...' > $src && \
    #       vm-put-file --cleanup $src /etc/motd
    local cleanup append invalid
    while [ "${1#-}" != "$1" -a -n "$1" ]; do
        case "$1" in
            --cleanup)
                cleanup=1
                shift
                ;;
            --append)
                append=1
                shift
                ;;
            *)
                invalid="${invalid}${invalid:+,}\"$1\""
                shift
                ;;
        esac
    done
    if [ -n "$cleanup" -a -n "$1" ]; then
        trap "rm -f $1" RETURN EXIT
    fi
    if [ -n "$invalid" ]; then
        error "invalid options: $invalid"
        return 1
    fi
    [ "$(dirname "$2")" == "." ] || vm-command-q "[ -d \"$(dirname "$2")\" ]" || vm-command "mkdir -p \"$(dirname "$2")\"" ||
        command-error "cannot create vm-put-file destination directory to VM"
    host-command "$SCP \"$1\" ${VM_SSH_USER}@${VM_IP}:\"vm-put-file.${1##*/}\"" ||
        command-error "failed to copy file to VM"
    if [ -z "$append" ]; then
        vm-command "mv \"vm-put-file.${1##*/}\" \"$2\"" ||
            command-error "failed to rename file"
    else
        vm-command "touch \"$2\" && cat \"vm-put-file.${1##*/}\" >> \"$2\" && rm -f \"vm-put-file.${1##*/}\"" ||
            command-error "failed to append file"
    fi
}

vm-pipe-to-file() { # script API
    # Usage: vm-pipe-to-file [--append] DST-VM-FILE
    #
    # Reads stdin and writes the content to DST-VM-FILE, creating any
    # intermediate directories necessary.
    #
    # Example:
    #   echo 'Ahoy, Matey...' | vm-pipe-to-file /etc/motd
    local tmp=$(mktemp vm-pipe-to-file.XXXXXX) append
    if [ "$1" = "--append" ]; then
        append="--append"
        shift
    fi
    cat > $tmp
    vm-put-file --cleanup $append $tmp $1
}

vm-sed-file() { # script API
    # Usage: vm-sed-file PATH-IN-VM SED-EXTENDED-REGEXP-COMMANDS
    #
    # Edits the given file in place with the given extended regexp
    # sed commands.
    #
    # Example:
    #   vm-sed-file /etc/motd 's/Matey/Guybrush Threepwood/'
    local file="$1" cmd
    shift
    for cmd in "$@"; do
        vm-command "sed -E -i \"$cmd\" $file" ||
            command-error "failed to edit $file with sed commands $@"
    done
}

vm-set-kernel-cmdline() { # script API
    # Usage: vm-set-kernel-cmdline E2E-DEFAULTS
    #
    # Adds/replaces E2E-DEFAULTS to kernel command line"
    #
    # Example:
    #   vm-set-kernel-cmdline nr_cpus=4
    #   vm-reboot
    #   vm-command "cat /proc/cmdline"
    #   launch cri-resmgr
    distro-set-kernel-cmdline "$@"
}

vm-reboot() { # script API
    # Usage: vm-reboot
    #
    # Reboots the virtual machine and waits that the ssh server starts
    # responding again.
    vm-command "reboot"
    sleep 5
    host-wait-vm-ssh-server
}

vm-networking() {
    vm-command-q "grep -q 1 /proc/sys/net/ipv4/ip_forward" || vm-command "sysctl -w net.ipv4.ip_forward=1"
    vm-command-q "grep -q ^net.ipv4.ip_forward=1 /etc/sysctl.conf" || vm-command "echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf"
    vm-command-q "grep -q 1 /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null" || {
        vm-command "modprobe br_netfilter"
        vm-command "echo br_netfilter > /etc/modules-load.d/br_netfilter.conf"
    }
    vm-command-q "grep -q \$(hostname) /etc/hosts" || vm-command "echo \"$VM_IP \$(hostname)\" >/etc/hosts"

    distro-setup-proxies
}

vm-install-cri-resmgr() {
    prefix=/usr/local
    if [ "$binsrc" == "github" ]; then
        vm-install-golang
        vm-install-pkg make
        vm-command "go get -d -v github.com/intel/cri-resource-manager"
        CRI_RESMGR_SOURCE_DIR=$(awk '/package.*cri-resource-manager/{print $NF}' <<< "$COMMAND_OUTPUT")
        vm-command "cd $CRI_RESMGR_SOURCE_DIR && make install && cd -"
    elif [ "${binsrc#packages/}" != "$binsrc" ]; then
        suf=$(vm-pkg-type)
        vm-command "rm -f *.$suf"
        local pkg_count
        pkg_count=$(ls "$HOST_PROJECT_DIR/$binsrc"/cri-resource-manager*.$suf | grep -v dbg | wc -l)
        if [ "$pkg_count" == "0" ]; then
            error "installing from $binsrc failed: cannot find cri-resource-manager_*.$suf from $HOST_PROJECT_DIR/$binsrc"
        elif [[ "$pkg_count" > "1" ]]; then
            error "installing from $binsrc failed: expected exactly one cri-resource-manager*.$suf in $HOST_PROJECT_DIR/$binsrc, found $pkg_count alternatives."
        fi
        host-command "$SCP $HOST_PROJECT_DIR/$binsrc/*.$suf $VM_SSH_USER@$VM_IP:/tmp" || {
            command-error "copying *.$suf to vm failed, run \"make cross-$suf\" first"
        }
        vm-install-pkg "/tmp/cri-resource-manager*.$suf" || {
            command-error "installing packages failed"
        }
        vm-command "systemctl daemon-reload"
    elif [ -z "$binsrc" ] || [ "$binsrc" == "local" ]; then
        local bin_change
        local src_change
        bin_change=$(stat --format "%Z" "$BIN_DIR/cri-resmgr")
        src_change=$(find "$HOST_PROJECT_DIR" -name '*.go' -type f | xargs stat --format "%Z" | sort -n | tail -n 1)
        if [[ "$src_change" > "$bin_change" ]]; then
            echo "WARNING:"
            echo "WARNING: Source files changed - installing possibly outdated binaries from"
            echo "WARNING: $BIN_DIR/"
            echo "WARNING:"
            sleep ${warning_delay}
        fi
        vm-put-file "$BIN_DIR/cri-resmgr" "$prefix/bin/cri-resmgr"
        vm-put-file "$BIN_DIR/cri-resmgr-agent" "$prefix/bin/cri-resmgr-agent"
    else
        error "vm-install-cri-resmgr: unknown binsrc=\"$binsrc\""
    fi
}

vm-cri-import-image() {
    local image_name="$1"
    local image_tar="$2"
    case "$VM_CRI" in
        containerd)
            vm-command "ctr -n k8s.io images import \"$image_tar\" >/dev/null 2>&1; crictl --runtime-endpoint unix:///run/containerd/containerd.sock images | grep \"$image_name\"" ||
                command-error "failed to import \"$image_tar\" on VM"
            ;;
        *)
            error "vm-cri-import-image unsupported container runtime: \"$VM_CRI\""
    esac
}

vm-install-cri-resmgr-webhook() {
    local service=cri-resmgr-webhook
    local namespace=cri-resmgr
    vm-command-q "\
        kubectl delete secret -n ${namespace} cri-resmgr-webhook-secret 2>/dev/null; \
        kubectl delete csr ${service}.${namespace} 2>/dev/null; \
        kubectl delete -f webhook/mutating-webhook-config.yaml 2>/dev/null; \
        kubectl delete -f webhook/webhook-deployment.yaml 2>/dev/null; \
        "
    local webhook_image_info webhook_image_id webhook_image_repotag webhook_image_tar webhook_image_manifest
    webhook_image_info="$(docker images --filter=reference=cri-resmgr-webhook --format '{{.ID}} {{.Repository}}:{{.Tag}} (created {{.CreatedSince}}, {{.CreatedAt}})' | head -n 1)"
    if [ -z "$webhook_image_info" ]; then
        error "cannot find cri-resmgr-webhook image on host, run \"make images\" and check \"docker images --filter=reference=cri-resmgr-webhook\""
    fi
    echo "installing webhook to VM from image: $webhook_image_info"
    sleep 2
    webhook_image_id="$(awk '{print $1}' <<< "$webhook_image_info")"
    webhook_image_repotag="$(awk '{print $2}' <<< "$webhook_image_info")"
    webhook_image_tar="$(realpath "$OUTPUT_DIR/webhook-image-$webhook_image_id.tar")"
    webhook_image_manifest="$OUTPUT_DIR/manifest.json"
    # It is better to export (save) the image with image_repotag rather than image_id
    # because otherwise manifest.json RepoTags will be null and containerd will
    # remove the image immediately after impoting it as part of garbage collection.
    docker image save "$webhook_image_repotag" > "$webhook_image_tar"
    vm-put-file "$webhook_image_tar" "webhook/$(basename "$webhook_image_tar")" || {
        command-error "copying webhook image to VM failed"
    }
    vm-cri-import-image cri-resmgr-webhook "webhook/$(basename "$webhook_image_tar")"
    # Install tools for creating webhook certificate: cfssl and jq
    vm-command-q "command -v cfssl" >/dev/null || {
        cat <<EOF | vm-pipe-to-file webhook/install-cfssl.sh
VERSION=\$(curl --silent "https://api.github.com/repos/cloudflare/cfssl/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
VNUMBER=\${VERSION#"v"}
wget -q https://github.com/cloudflare/cfssl/releases/download/\${VERSION}/cfssl_\${VNUMBER}_linux_amd64 -O cfssl
chmod +x cfssl
mv cfssl /usr/local/bin
EOF
        vm-command "chmod a+x webhook/install-cfssl.sh; webhook/install-cfssl.sh"
    }
    vm-command-q "command -v jq" >/dev/null || {
        vm-install-pkg jq
    }
    # Create webhook certificate
    cat <<EOF | vm-pipe-to-file webhook/csr-config.json
{
    "CN": "${service}.${namespace}.svc",
    "hosts": [
        "${service}",
        "${service}.${namespace}",
        "${service}.${namespace}.svc"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    }
}
EOF
    vm-command "cfssl genkey -loglevel=2 webhook/csr-config.json > webhook/csr.json"
    vm-command "jq --raw-output '.key' webhook/csr.json > webhook/server-key.pem"
    vm-command "jq --raw-output '.csr' webhook/csr.json > webhook/server.csr"
    local server_csr_b64
    server_csr_b64="$(vm-command-q "cat webhook/server.csr" | base64 -w 0)"
    cat <<EOF | vm-pipe-to-file webhook/csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${service}.${namespace}
spec:
  request: ${server_csr_b64}
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
    kubectl create -f webhook/csr.yaml
    vm-wait-until "kubectl get csr | grep -q  ${service}.${namespace}" ||
        error "creating certificate signing request failed"
    kubectl certificate approve "${service}.${namespace}" ||
        error "approving certificate signing request failed"
    vm-wait-until "kubectl get csr | grep ${service}.${namespace} | grep Issued" ||
        error "certificate signing request not Issued after approval"
    vm-command "kubectl get csr ${service}.${namespace} -o jsonpath='{.status.certificate}' | base64 -d > webhook/server-crt.pem"
    # Allow webhook to run on node tainted by cmk=true
    sed -e "s|IMAGE_PLACEHOLDER|$webhook_image_repotag|" \
        -e 's|^\(\s*\)tolerations:$|\1tolerations:\n\1  - {\"key\": \"cmk\", \"operator\": \"Equal\", \"value\": \"true\", \"effect\": \"NoSchedule\"}|g' \
        -e 's/imagePullPolicy: Always/imagePullPolicy: Never/' \
        < "${HOST_PROJECT_DIR}/cmd/cri-resmgr-webhook/webhook-deployment.yaml" \
        | vm-pipe-to-file webhook/webhook-deployment.yaml
    # Create secret that contains svc.crt and svc.key for webhook deployment
    local server_crt_b64 server_key_b64
    server_crt_b64="$(vm-command-q "cat webhook/server-crt.pem" | base64 -w 0)"
    server_key_b64="$(vm-command-q "cat webhook/server-key.pem" | base64 -w 0)"
    cat <<EOF | vm-pipe-to-file --append webhook/webhook-deployment.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: cri-resmgr-webhook-secret
  namespace: cri-resmgr
data:
  svc.crt: ${server_crt_b64}
  svc.key: ${server_key_b64}
type: Opaque
EOF
    local cabundle_b64
    cabundle_b64="$(vm-command-q "kubectl get configmap -n kube-system extension-apiserver-authentication -o=jsonpath='{.data.client-ca-file}' | tee webhook/client-ca-file" | base64 -w 0)"
    sed -e "s/CA_BUNDLE_PLACEHOLDER/${cabundle_b64}/" \
        < "${HOST_PROJECT_DIR}/cmd/cri-resmgr-webhook/mutating-webhook-config.yaml" \
        | vm-pipe-to-file webhook/mutating-webhook-config.yaml
}

vm-pkg-type() {
    distro-pkg-type
}

vm-install-pkg() {
    distro-install-pkg "$@"
}

vm-install-golang() {
    distro-install-golang
}

vm-install-cri() {
    case "${VM_CRI}" in
        containerd)
            distro-install-containerd
            ;;
        crio)
            distro-install-crio
            ;;
        *)
            command-error "unsupported CRI runtime \"$VM_CRI\" requested"
            ;;
    esac
}

vm-install-containernetworking() {
    vm-install-golang
    vm-command "go get -d github.com/containernetworking/plugins"
    CNI_PLUGINS_SOURCE_DIR=$(awk '/package.*plugins/{print $NF}' <<< $COMMAND_OUTPUT)
    [ -n "$CNI_PLUGINS_SOURCE_DIR" ] || {
        command-error "downloading containernetworking plugins failed"
    }
    vm-command "pushd \"$CNI_PLUGINS_SOURCE_DIR\" && ./build_linux.sh && mkdir -p /opt/cni && cp -rv bin /opt/cni && popd" || {
        command-error "building and installing cri-tools failed"
    }
    vm-command 'rm -rf /etc/cni/net.d && mkdir -p /etc/cni/net.d && cat > /etc/cni/net.d/10-bridge.conf <<EOF
{
  "cniVersion": "0.4.0",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "10.217.0.0/16",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF'
    vm-command 'cat > /etc/cni/net.d/20-portmap.conf <<EOF
{
    "cniVersion": "0.4.0",
    "type": "portmap",
    "capabilities": {"portMappings": true},
    "snat": true
}
EOF'
    vm-command 'cat > /etc/cni/net.d/99-loopback.conf <<EOF
{
  "cniVersion": "0.4.0",
  "name": "lo",
  "type": "loopback"
}
EOF'
}

vm-install-k8s() {
    distro-install-k8s
}

vm-create-singlenode-cluster-cilium() {
    vm-create-singlenode-cluster
    vm-install-cni-cilium
    if ! vm-command "kubectl wait --for=condition=Ready node/\$(hostname) --timeout=120s"; then
        command-error "kubectl waiting for node readiness timed out"
    fi
}

vm-create-singlenode-cluster() {
    vm-command "kubeadm init --pod-network-cidr=10.217.0.0/16 --cri-socket /var/run/cri-resmgr/cri-resmgr.sock"
    if ! grep -q "initialized successfully" <<< "$COMMAND_OUTPUT"; then
        command-error "kubeadm init failed"
    fi
    vm-command "mkdir -p \$HOME/.kube"
    vm-command "cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    vm-command "kubectl taint nodes --all node-role.kubernetes.io/master-"
}

vm-install-cni-cilium() {
    vm-command "kubectl create -f https://raw.githubusercontent.com/cilium/cilium/v1.8/install/kubernetes/quick-install.yaml"
    if ! vm-command "kubectl rollout status --timeout=360s -n kube-system daemonsets/cilium"; then
        command-error "installing cilium CNI to Kubernetes timed out"
    fi
}

vm-print-usage() {
    echo "- Login VM:     ssh $VM_SSH_USER@$VM_IP"
    echo "- Stop VM:      govm stop $VM_NAME"
    echo "- Delete VM:    govm delete $VM_NAME"
}

vm-check-env || exit 1
