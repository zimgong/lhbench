#!/bin/bash
# A script to collect the runtime statistics of the Spark jobs
# Author: Zim Gong

# Define the directory to store the Spark runtime statistics
ssh_user=$(whoami)

echo "Welcome $ssh_user"

# TODO: Check the consecutive IPs to determine which nodes are available

# Get the user's IP address
cluster_hostname=$(ifconfig -a | grep -oP 'inet \K10\.164\.\d{1,3}\.\d{1,3}' | head -n1)
pem_file="/home/$ssh_user/.ssh/id_rsa"
source_path="/input"

ip_base=${cluster_hostname%.*}.
start=${cluster_hostname##*.}
echo "Cluster hostname: $cluster_hostname"
echo "Setting the tool configurations..."
sshed_base=" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICwaAq9LI48vVO4qbt35Xfz1pi+RE1Krq1iIeJQqoFEw"
HADOOP_PATH="${HADOOP_HOME}/etc/hadoop"

ip_addresses=()
email_addresses=()

workers_file="${HADOOP_PATH}/workers"

if [[ "$(head -n 1 "$workers_file")" == "$cluster_hostname" ]]; then
    echo "The current IP address is already present in conf, cluster initialized."
else
    echo "The current IP address does not match any entry in $workers_file"
    pkill -f metastore
    cd /home/$ssh_user/mysql

    # TODO: Fix MySQL shutdown and restart issue. Currently cannot login again with the old password

    if [ -S "/home/$ssh_user/mysql/mysql.sock" ]; then
        # rm ./mysql.sock.lock
        # rm ./mysql.sock
        # rm ./mysql.pid
        bin/mysqladmin -uroot -p shutdown -S mysql.sock --password=111
        rm -rf ~/data
    fi

    stop-dfs.sh
    stop-yarn.sh

    echo "Services reset completed, starting to configure the cluster..."

    ## change ssh config
    rm -rf "${HADOOP_PATH}/workers"
    rm -rf ~/.ssh/known_hosts
    for i in $(seq 0 2); do
        ip_addresses+=("${ip_base}$(($start + $i))")
        email_addresses+=("gl$(($start + $i + 2950)).arc-ts.umich.edu")
        echo "${ip_addresses[i]},${email_addresses[i]}${sshed_base}" >> ~/.ssh/known_hosts
        echo "${ip_addresses[i]}" >> "${HADOOP_PATH}/workers"
    done

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
    SC="${SPARK_HOME}/conf/spark-defaults.conf"
    cp "${SC}.template" "$SC"
    sed -i "s/namenode/${ip_addresses[0]}/g" $SC

    hdfs namenode -format
    start-dfs.sh
    start-yarn.sh
    # put the data in the hdfs
    hdfs dfs -mkdir /input
    hdfs dfs -mkdir /spark-logs
    hdfs dfs -put -f ~/tpcds-2.13/tpcds_sf1_parquet/* /input &

    # mysql start
    cd ~/mysql
    bin/mysqld --defaults-file=my.cnf --initialize
    password=$(grep -oP 'root@localhost:\K.*' log/*.log | tail -n 1)
    bin/mysqld_safe --defaults-file=my.cnf &
    mysql --defaults-file=my.cnf -u root -p"${password}" < /home/${ssh_user}/lhbench/set_mysql.txt

    schematool -initSchema -dbType mysql -vebin/mysqld_safe --defaults-file=my.cnf
    hive --service metastore &
    echo "Cluster initialized."

fi

cd /home/$ssh_user/lhbench

# Define the user-defined jobs
# TODO: Complete the configuration of non-TPCDS jobs
job_counter=1
STOP_AFTER=1
while IFS=' ' read -r engine test rest_of_line; do
    # Check if the engine type is valid
    if [[ "$engine" == "delta" || "$engine" == "iceberg" || "$engine" == "hudi" ]]; then
        # Construct the job command based on the engine type and the rest of the line
        if [[ "$test == tpcds" ]]; then
            load_command="./run-benchmark.py \
                --cluster-hostname ${cluster_hostname} \
                -i ${pem_file} \
                --ssh-user ${ssh_user} \
                --source-path ${source_path} \
                --benchmark-path /output/load-1gb \
                --benchmark tpcds-${rest_of_line}-${engine}-load"
            query_command="./run-benchmark.py \
                --cluster-hostname ${cluster_hostname} \
                -i ${pem_file} \
                --ssh-user ${ssh_user} \
                --benchmark-path /output/load-1gb \
                --benchmark tpcds-${rest_of_line}-${engine}"
            echo "Job $job_counter: $engine $test $rest_of_line"
            $load_command
            $query_command
        elif [[ "$test == refresh" ]]; then
            strategy=$rest_of_line[0]
            run_command="./run-benchmark.py \
                --cluster-hostname ${cluster_hostname} \
                -i ${pem_file} \
                --ssh-user ${ssh_user}"
            echo "Job $job_counter: $engine $test $rest_of_line"
            $run_command
        elif [[ "$test == merge" ]]; then
            echo "Job $job_counter: $engine $test $rest_of_line"
        elif [[ "$test == count" ]]; then
            load_command="./run-benchmark.py \
                --cluster-hostname ${cluster_hostname} \
                -i ${pem_file} \
                --ssh-user ${ssh_user} \
                --benchmark-path /output/sorted-${rest_of_line}-${engine} \
                --benchmark ${rest_of_line}-files-sorted-${engine}-load"
            query_command="./run-benchmark.py \
                --cluster-hostname ${cluster_hostname} \
                -i ${pem_file} \
                --ssh-user ${ssh_user} \
                --benchmark-path /output/sorted-${rest_of_line}-${engine} \
                --cloud-provider hdfs \
                --benchmark ${rest_of_line}-files-sorted-${engine}-query"
            echo "Job $job_counter: $engine $test $rest_of_line"
            $load_command
            $query_command
        else 
            echo "Invalid test type: $test at line $job_counter"
        fi
    else
        echo "Invalid engine type: $engine at line $job_counter"
    fi
    if [[ "$job_counter" == "$STOP_AFTER" ]]; then
        break
    fi
    ((job_counter++))
done < job_list.txt

STATS_DIR="/home/$ssh_user/spark-stats"

# Create STATS_DIR if it does not exist
if [ ! -d "$STATS_DIR" ]; then
    mkdir -p "$STATS_DIR"
fi

# Check if Spark History Server is already running
if ! pgrep -f "org.apache.spark.deploy.history.HistoryServer" >/dev/null; then
    # Start Spark History Server
    ${SPARK_HOME}/sbin/start-history-server.sh
fi

# Wait until localhost:18080 is available
while ! nc -z localhost 18080; do
    sleep 1
done

FOLDER_NAME=${STATS_DIR}/$(date +"%Y%m%d_%H%M%S")

if [ ! -d "$FOLDER_NAME" ]; then
    mkdir -p "$FOLDER_NAME"
fi

# Download data from localhost:18080/api and save it in the folder
wget -qO "${FOLDER_NAME}/api.json" http://localhost:18080/api/v1/applications

# Get the application IDs and reverse the order to match the order of the jobs
ids=$(jq -r '.[] | .id' "${FOLDER_NAME}/api.json" | tac)

# Read the job_list.txt file and store the task names in an array
task_names=()
while IFS= read -r line; do
    task_name="${line// /_}"
    task_names+=("$task_name")
done < job_list.txt

counter=0
for id in $ids; do
    # Find the corresponding task name for the current ID
    task_name="${task_names[$counter]}"

    # Create a subfolder with the task name
    subfolder_name="${FOLDER_NAME}/${task_name}"
    if [ ! -d "$subfolder_name" ]; then
        mkdir -p "$subfolder_name"

    fi

    ((counter++))
done
