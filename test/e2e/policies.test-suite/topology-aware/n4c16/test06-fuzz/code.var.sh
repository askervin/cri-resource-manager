source $TEST_DIR/codelib.sh || {
    echo "error importing lib.sh"
    exit 1
}

( kubectl delete pods rgu0 rbu0 rbe0 -n kube-system --now ) || true

gencodes=0
for genscript in "$TEST_DIR"/generated*.sh; do
    if [ ! -f "$genscript" ]; then
        continue
    fi
    (
        paralleloutdir="$outdir/parallel$gencodes"
        [ -d "$paralleloutdir" ] && rm -rf "$paralleloutdir"
        mkdir "$paralleloutdir"
        OUTPUT_DIR="$paralleloutdir"
        COMMAND_OUTPUT_DIR="$paralleloutdir/commands"
        mkdir "$COMMAND_OUTPUT_DIR"
        source "$genscript" 2>&1 | sed -u -e "s/^/$(basename "$genscript"): /g"
    ) &
    gencodes=$(( gencodes + 1))
done

if [[ "$gencodes" == "0" ]]; then
    echo "Test verdict: SKIP (no generated fuzz tests)"
    exit 0
fi

echo "============================================"
echo "============================================"
echo "============================================"
echo "============================================"
echo "waiting..."

wait
