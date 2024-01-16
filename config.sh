#!/bin/bash


cd ..
ip=$(ifconfig -a | grep -oP 'inet \K10\.164\.\d{1,3}\.\d{1,3}' | head -n1)
ip_base=${ip%.*}.
start=${ip##*.}
echo "First part: $ip_base"
echo "Second part: $start"
sshed_base=" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICwaAq9LI48vVO4qbt35Xfz1pi+RE1Krq1iIeJQqoFEw"
HADOOP_PATH="${HADOOP_HOME}/etc/hadoop"

ip_addresses=()
email_addresses=()

## change ssh config
rm -rf "${HADOOP_PATH}/workers"
rm -rf ~/.ssh/known_hosts
for i in $(seq 0 2); do
    ip_addresses+=("${ip_base}$(($start + $i))")
    email_addresses+=("gl$(($start + $i + 2950)).arc-ts.umich.edu")
    echo "${ip_addresses[i]},${email_addresses[i]}${sshed_base}" >> ~/.ssh/known_hosts
    echo "${ip_addresses[i]}" >> "${HADOOP_PATH}/workers"
done
# echo "${ip_addresses[0]}", "${ip_addresses[1]}", "${ip_addresses[2]}"
# echo "${email_addresses[0]}", "${email_addresses[1]}", "${email_addresses[2]}"

## change hadoop config

CT="${HADOOP_PATH}/core-site.xml"
cp "${CT}.template" "$CT"
sed -i "s/hadoop1:9000/${ip_addresses[0]}:9000/g" $CT

HDFS="${HADOOP_PATH}/hdfs-site.xml"
cp "${HDFS}.template" "$HDFS"
sed -i "s/hadoop2:50090/${ip_addresses[1]}:50090/g" $HDFS

YN="${HADOOP_PATH}/yarn-site.xml"
cp "${YN}.template" "$YN"
sed -i "s/hadoop3/${ip_addresses[2]}/g" $YN

## change hive conf
HS="${HIVE_HOME}/conf/hive-site.xml"
cp "${HS}.template" "$HS"
sed -i "s/hadoop1:3306/${ip_addresses[0]}:3306/g" $HS

## change spark conf
SS="${SPARK_HOME}/conf/hive-site.xml"
cp "${SS}.template" "$SS"
sed -i "s/hadoop1/${ip_addresses[0]}/g" $SS
