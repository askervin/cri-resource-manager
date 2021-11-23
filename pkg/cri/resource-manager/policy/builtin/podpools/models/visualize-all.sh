#!/bin/bash

outdir=${1:-.}

for fillorder in FillFirstFree FillBalanced FillPacked FillMinCPU FillMaxCPU FillMaxPods; do
    echo "Creating $fillorder.png"
    remote_py3aal fillorder.aal -S pools --lsts-depth 30 -D "$fillorder" -o - | fmbt3-view -f png -o "$outdir/$fillorder.png" -
done
