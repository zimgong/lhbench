#!/usr/bin/env bash
#
# Run 1GB TPC-DS Load

SCALE=1
USER=zimgong
RUNID=1
PCT=0.001

export RUNID=$(date+%Y%M%D%H%M%S)

./run-benchmark.py \
    --cluster-hostname $(ifconfig -a | grep -oP 'inet \K10\.164\.\d{1,3}\.\d{1,3}' | head -n1) \
    -i /home/zimgong/.ssh/id_rsa \
    --ssh-user zimgong \
    --benchmark-path "/lhbench-tables-microbenchmark-$USER/delta/${RUNID}" \
    --db-name "deltamicrosf${SCALE}gb${RUNID}" \
    --partition-table false \
    --source-percent $PCT \
    --benchmark "merge-micro-${SCALE}gb-hudi-mor"