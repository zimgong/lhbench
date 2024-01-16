#!/bin/bash

cd ..

# start hadoop
hdfs namenode -format
start-dfs.sh
start-yarn.sh
# put the data in the
hdfs dfs -mkdir /input
hdfs dfs -put -f ~/tpcds-2.13/tpcds_sf1_parquet/* /input &

# mysql start
cd ~/mysql
bin/mysqld --defaults-file=my.cnf --initialize
cat log/*.log | grep 'root@localhost'
bin/mysqld_safe --defaults-file=my.cnf &
bin/mysql --defaults-file=my.cnf -u root -p

# ALTER USER 'root'@'localhost' IDENTIFIED BY '111';
# update mysql.user set host='%' where user='root';
# FLUSH PRIVILEGES;
# EXIT;