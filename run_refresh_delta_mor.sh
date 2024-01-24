#!/usr/bin/env bash
#
# Run Delta refresh

SCALE=1
USER=zimgong
RUNID=1

./run-benchmark.py \
    --cluster-hostname 10.164.9.147 \
    -i /home/zimgong/.ssh/id_rsa \
    --ssh-user zimgong \
    --scale $SCALE \
    --source-path /cow \
    --cache-path "/lhbench-cache-$USER/${SCALE}gb" \
    --benchmark-path "/lhbench-tables-$USER/${SCALE}gb/delta" \
    --db-name "deltasf${SCALE}gb" \
    --refresh-count 10 \
    --iterations 3 \
    --table-mode cow \
    --partition-tables true \
    --benchmark tpcds-custom-ingestion-delta