#!/bin/bash

# Usage: VAR=VALUE post-process.sh output-CRICONFIGNAME1 output-CRICONFIGNAME2...
# VARs:
#   normalize=1..  # normalizes plotted values so that the smallest is 1.00
#   normalize=0..1 # normalizes plotted to values between 0.0 and 1.0
#                  # if normalize="", values are not normalized
#   maxy=MAXY      # maximum value on the Y axis
#   ytrans=log2    # logarithmic Y axis, the default ytrans is 'identity'
#   save=PREFIX    # create PREFIX.svg and PREFIX.csv. The default is 'plot'.
#   filter=REGEXP  # show only the result lines that match REGEXP.

normalize="${normalize:-}"
maxy="${maxy:-}"
ytrans="${ytrans:-identity}"
save="${save:-plot}"
filter="${filter:-.}"

(
    for out_path in "$@"; do (
        benchmark_dir=$out_path/benchmark
        out_dir="$(basename "$out_path")"
        cd "$benchmark_dir" || exit
        for bgload in *; do (
            cd "$bgload" || exit
            for memtier_results in BM_MEMTIER-*; do
                ops=\$2
                p50latency=\$6
                p99latency=\$7
                p999latency=\$8
                awk "/Totals/{print \"$out_dir $bgload $memtier_results \"$p50latency\" \"$p99latency\" \"$p999latency\" \"$ops}" < "$memtier_results"
            done
        ); done
    ); done
) > total-latencies.txt

sed -e 's/output-//g' -e 's/BG_//g' -e 's/BM_MEMTIER-//g' -e 's/-cpu-[0-9]*.txt//g' < total-latencies.txt | awk '{print $1" "$2" "$3" "$4" "$5" "$6" "$7}' | grep -E "$filter" > data.txt

cat > plot.R <<EOF
library(ggplot2)
library(svglite)
d <- read.table(file="data.txt")
names(d) <- c("cri_conf", "bg_load", "annotations", "p50", "p99", "p999", "ops")

if ("$normalize" == "1..") {
    smallest_value = min(d[c("p50", "p99", "p999")])
    d[c("p50", "p99", "p999")] = d[c("p50", "p99", "p999")] / smallest_value
    cat("normalized to 1.., the smallest value was", smallest_value, "\n")
    latency_unit = "the fastest is 1.0"
} else if ("$normalize" == "0..1") {
    smallest_value = min(d[c("p50", "p99", "p999")])
    largest_value = max(d[c("p50", "p99", "p999")])
    distance = largest_value - smallest_value
    d[c("p50", "p99", "p999")] = (d[c("p50", "p99", "p999")] - smallest_value) / distance
    cat("normalized to 0..1 the smallest value was", smallest_value, "and the largest", largest_value, "\n")
    latency_unit = "normalized between 0..1"
} else if ("$normalize" == "") {
    cat("not normalizing values\n")
    latency_unit = "ms"
} else {
    stop("invalid 'normalize' value")
}

if ("$maxy" == "") {
    maxy=NA
} else {
    maxy=as.double("$maxy")
    cat("liming y axis to", maxy, "\n")
}

d[c("p50", "p99", "p999")] = round(d[c("p50", "p99", "p999")], 2)
image = (
    ggplot(d, aes(x=bg_load, group=cri_conf, shape=cri_conf), ylim=c(0, maxy))
    + ggtitle("Memtier_benchmark total latencies")
    + ylab(paste("Latency (", latency_unit, ")", sep=""))
    + xlab("Background load (stress-ng)")
    + labs(linetype="Percentiles")
    + labs(color="Configurations")
    + geom_line(aes(color=cri_conf, linetype="50 %", y=p50))
    + geom_line(aes(color=cri_conf, linetype="99 %", y=p99))
    + geom_line(aes(color=cri_conf, linetype="99.9 %", y=p999))
    + scale_x_discrete(limits=c("NOLOAD", "SHM", "CPUALL", "CPUJMP", "MEMCPY", "STREAM"))
    + scale_y_continuous(limits=c(NA, maxy), trans='$ytrans')
    )
# print full data matrix
d
print("saving $save.csv")
write.csv(d, file="$save.csv", row.names=FALSE)
print("saving $save-lat.svg")
ggsave(file="$save-lat.svg", plot=image)

image_ops = (
    ggplot(d, aes(x=bg_load, group=cri_conf, shape=cri_conf), ylim=c(0, maxy))
    + ggtitle("Memtier_benchmark total throughput")
    + ylab(paste("Throughput (operations/second)", sep=""))
    + xlab("Background load (stress-ng)")
    + labs(color="Configurations")
    + geom_line(aes(color=cri_conf, linetype="ops", y=ops))
    + scale_x_discrete(limits=c("NOLOAD", "SHM", "CPUALL", "CPUJMP", "MEMCPY", "STREAM"))
    + scale_y_continuous(limits=c(NA, maxy), trans='$ytrans')
    )
print("saving $save-ops.svg")
ggsave(file="$save-ops.svg", plot=image_ops)

EOF
Rscript plot.R
