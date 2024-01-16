#!/usr/bin/env bash
#
# Run 1k File Count Load

ip=$(ifconfig -a | grep -oP 'inet \K10\.164\.\d{1,3}\.\d{1,3}' | head -n1)

./run-benchmark.py \
    --cluster-hostname ${ip} \
     -i /home/zimgong/.ssh/id_rsa \
    --ssh-user zimgong \
    --benchmark-path /output/sorted-1k-delta \
    --benchmark 1k-files-sorted-delta-load