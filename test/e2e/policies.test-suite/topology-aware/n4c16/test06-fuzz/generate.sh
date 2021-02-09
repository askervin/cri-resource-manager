#!/bin/bash

usage() {
    cat <<EOF
generate.sh - generate fuzz tests.

Configuring test generation with environment variables:
  TESTCOUNT=<NUM>       Number of generated test scripts than run in parallel.
  MEM=<NUM>             Memory [MB] available for all pods in the system.
  CPU=<NUM>             Non-reserved CPU [mCPU] available for all pods in the system.
  RESERVED_CPU=<NUM>    Reserved CPU [mCPU] available for all pods in the system.
  STEPS=<NUM>           Total number of test steps in all parallel tests.
EOF
    exit 0
}

if [ -n "$1" ]; then
    usage
fi

TESTCOUNT=${TESTCOUNT:-1}
MEM=${MEM:-8000}
CPU=${CPU:-15000}
RESERVED_CPU=${RESERVED_CPU:-1000}
STEPS=${STEPS:-100}

mem_per_test=$(( MEM / TESTCOUNT ))
cpu_per_test=$(( CPU / TESTCOUNT ))
reserved_cpu_per_test=$(( RESERVED_CPU / TESTCOUNT ))
steps_per_test=$(( STEPS / TESTCOUNT ))

cd "$(dirname "$0")" || {
    echo "cannot cd to the directory of $0"
    exit 1
}

for testnum in $(seq 1 "$TESTCOUNT"); do
    testid=$(( testnum - 1))
    sed -e "s/max_mem=.*/max_mem=${mem_per_test}/" \
        -e "s/max_cpu=.*/max_cpu=${cpu_per_test}/" \
        -e "s/max_reserved_cpu=.*/max_reserved_cpu=${reserved_cpu_per_test}/" \
        < fuzz.aal > tmp.fuzz.aal
    sed -e "s/fuzz\.aal/tmp.fuzz.aal/" \
        -e "s/pass = steps(.*/pass = steps(${steps_per_test})/" \
        < fuzz.fmbt.conf > tmp.fuzz.fmbt.conf
    OUTFILE=generated${testid}.sh
    echo "generating $OUTFILE..."
    docker run -v "$(pwd):/mnt/models" fmbt:latest sh -c 'cd /mnt/models; fmbt tmp.fuzz.fmbt.conf 2>/dev/null | fmbt-log -f \$as\$al' | grep -v AAL | sed -e 's/^, /  /g' -e 's/^\([^i].*\)/echo "expected: \1"/g' -e 's/^i:\(.*\)/\1; kubectl get pods -A; vm-command "date +%T.%N"/g' | sed "s/\([^a-z0-9]\)\(r\?\)\(gu\|bu\|be\)\([0-9]\)/\1t${testid}\2\3\4/g" > "$OUTFILE"
done
