source "$(dirname "${BASH_SOURCE[0]}")/command.bash"

HOST_PROMPT=${HOST_PROMPT-"\e[38;5;11mhost>\e[0m "}
HOST_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
HOST_PROJECT_DIR="$(dirname "$(dirname "$(realpath "$HOST_LIB_DIR")")")"
GOVM=${GOVM-govm}

host-command() {
    command-start "host" "$HOST_PROMPT" "$1"
    bash -c "$COMMAND" 2>&1 | command-handle-output
    command-end ${PIPESTATUS[0]}
    return $COMMAND_STATUS
}

host-require-govm() {
    command -v "$GOVM" >/dev/null || error "cannot run govm \"$GOVM\". Check PATH or set GOVM=/path/to/govm."
}

host-set-vm-config() {
    if [ -z "$1" ]; then
        error "can't configure VM, name not set"
    fi
    if [ -z "$2" ]; then
        error "can't configure VM, distro not set"
    fi
    if [ -z "$3" ]; then
        error "can't configure VM, CRI runtime not set"
    fi
    VM_NAME="$1"
    VM_DISTRO="$2"
    VM_CRI="$3"
    VM_SSH_USER=$(vm-ssh-user)
}

host-fetch-vm-image() {
    local url=$(vm-image-url)
    local file=$(basename $url)
    local image decompress
    case $file in
        *.xz)
            image=${file%.xz}
            decompress="xz -d"
            ;;
        *.bz2)
            image=${file%.bz2}
            decompress="bzip -d"
            ;;
        *.gz)
            image=${file%.gz}
            decompress="gzip -d"
            ;;
        *)
            image="$file"
            decompress=":"
            ;;
    esac
    [ -f "$image" ] || {
        echo "VM image $image not found..."
        [ -f "$file" ] || {
            echo "downloading VM image $image..."
            host-command "wget --progress=dot:giga \"$url\"" ||
                error "failed to download VM image ($url)"
        }
        if [ -n "$decompress" ]; then
            echo "decompressing VM image $file..."
            $decompress $file || error "failed to decompress $file to $image using $decompress"
        fi
        if [ ! -f "$image" ]; then
            error "internal error, fetching+decompressing $url did not produce $image"
        fi
    }
    VM_IMAGE=$image
}

host-create-vm() {
    # Usage: host-create-vm NAME [NUMANODELIST_JSON]
    #
    # If successful, VM_IP variable contains the IP address of the govm guest.
    #
    # If NUMANODELIST_JSON is given, Qemu CPU and memory parameters are
    # generated from it. Example, create VM with four identical NUMA nodes:
    #     host-create-vm myvm '[{"cpu": 2, "mem": "2G", "nodes": 4}]'
    #
    # If NUMANODELIST_JSON is not given, Qemu CPU and memory parameters
    # can be defined directly in VM_QEMU_CPUMEM environment variable.
    # VM_QEMU_CPUMEM is expected to contain at least parameters
    #     -m MEMORY -smp CPUCORES
    #
    # Example: four numa nodes, 2 cores each
    #     VM_QEMU_CPUMEM="-m 8G,slots=4,maxmem=32G \
    #         -smp cpus=8 \
    #         -numa node,cpus=0-1,nodeid=0 \
    #         -numa node,cpus=2-3,nodeid=1 \
    #         -numa node,cpus=4-5,nodeid=2 \
    #         -numa node,cpus=6-7,nodeid=3 \
    #         -cpu host"
    #     host-create-vm my-four-numa-node-pc
    #
    # If NUMANODELIST_JSON parameter or VM_QEMU_CPUMEM environment
    # variable defined, the VM will be created with "govm compose" and
    # VM_GOVM_COMPOSE_TEMPLATE yaml. In both cases parameters in
    # VM_QEMU_EXTRA environment variable are passed through to Qemu.
    #
    # Debug Qemu parameters and output with
    #     $ docker logs $(docker ps | awk '/govm/{print $1; exit}')
    #
    local TOPOLOGY="$2"

    if [ -z "$VM_NAME" ]; then
        error "cannot create VM: missing name"
    fi
    if [ -n "$TOPOLOGY" ]; then
        if [ -n "$VM_QEMU_CPUMEM" ]; then
            error "cannot take both VM_QEMU_CPUMEM and numa node JSON"
        fi
        VM_QEMU_CPUMEM=$(echo "$TOPOLOGY" | "$HOST_LIB_DIR/topology2qemuopts.py")
        if [ "$?" -ne  "0" ]; then
            error "error in topology"
        fi
    fi
    host-require-govm
    # If VM does not exist, create it from scrach
    ${GOVM} ls | grep -q "$VM_NAME" || {
        host-fetch-vm-image
        vm-compose-govm-template > $vm.yaml
        host-command "${GOVM} compose -f $vm.yaml"
    }

    sleep 1
    VM_CONTAINER_ID=$(${GOVM} ls | awk "/$VM_NAME/{print \$1}")
    echo "# VM Docker container: $VM_CONTAINER_ID"
    # Verify Qemu version. Refuse to run if Qemu < 5.0.
    # Use "docker run IMAGE" instead of "docker exec CONTAINER",
    # because the container may have already failed.
    VM_CONTAINER_IMAGE=$(docker inspect $VM_CONTAINER_ID | jq '.[0].Image' -r | awk -F: '{print $2}')
    echo "# VM Docker image: $VM_CONTAINER_IMAGE"
    if [ -n "$VM_CONTAINER_IMAGE" ]; then
        VM_CONTAINER_QEMU_VERSION=$(docker run --entrypoint=/usr/bin/qemu-system-x86_64 $VM_CONTAINER_IMAGE -version | awk '/QEMU emulator version/{print $4}')
    fi
    if [ -n "$VM_CONTAINER_QEMU_VERSION" ]; then
        if [[ "$VM_CONTAINER_QEMU_VERSION" > "5" ]]; then
            echo "# VM Qemu version: $VM_CONTAINER_QEMU_VERSION"
        else
            if [[ "$QEMU_CPUMEM" =~ ",dies=" ]]; then
                error "Too old Qemu version \"$VM_CONTAINER_QEMU_VERSION\". Topology with dies > 1 requires Qemu >= 5.0"
            else
                echo "# (Your Qemu does not support dies > 1, consider updating for full topology support)"
            fi
        fi
    else
        echo "Warning: cannot verify Qemu version on govm image. In case of failure, check it is >= 5.0" >&2
    fi
    echo "# VM Qemu output : docker logs $VM_CONTAINER_ID"
    echo "# VM Qemu monitor: docker exec -it $VM_CONTAINER_ID nc local:/data/monitor"
    VM_MONITOR="docker exec -i $VM_CONTAINER_ID nc local:/data/monitor"
    host-wait-vm-ssh-server
}

host-wait-vm-ssh-server() {
    VM_IP=$(${GOVM} ls | awk "/$VM_NAME/{print \$4}")
    while [ "x$VM_IP" == "x" ]; do
        host-command "${GOVM} start \"$VM_NAME\""
        sleep 5
        VM_IP=$(${GOVM} ls | awk "/$VM_NAME/{print \$4}")
    done
    echo "# VM SSH server  : ssh $VM_SSH_USER@$VM_IP"

    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$VM_IP" >/dev/null 2>&1
    retries=60
    retries_left=$retries
    while ! $SSH ${VM_SSH_USER}@${VM_IP} -o ConnectTimeout=2 true 2>/dev/null; do
        if [ "$retries" == "$retries_left" ]; then
            echo -n "Waiting for VM SSH server to respond..."
        fi
        sleep 2
        echo -n "."
        retries_left=$(( $retries_left - 1 ))
        if [ "$retries_left" == "0" ]; then
            error "timeout"
        fi
    done
    [ "$retries" == "$retries_left" ] || echo ""
}

host-stop-vm() {
    #VM_NAME=$1
    host-require-govm
    host-command "${GOVM} stop $VM_NAME" || {
        command-error "stopping govm \"$VM_NAME\" failed"
    }
}

host-delete-vm() {
    #VM_NAME=$1
    host-require-govm
    host-command "${GOVM} delete $VM_NAME" || {
        command-error "deleting govm \"$VM_NAME\" failed"
    }
}
