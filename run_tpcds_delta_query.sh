#!/usr/bin/env bash
#
# Run 1GB TPC-DS Query

ip=$(ifconfig -a | grep -oP 'inet \K10\.164\.\d{1,3}\.\d{1,3}' | head -n1)

./run-benchmark.py \
    --cluster-hostname ${ip} \
    -i /home/zimgong/.ssh/id_rsa \
    --ssh-user zimgong \
    --benchmark-path /output/load-1gb \
    --benchmark tpcds-1gb-delta