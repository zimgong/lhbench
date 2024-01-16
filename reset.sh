#!/bin/bash

# stop hive metastore service
pkill -f metastore

# stop the mysql socket
cd ~/mysql
bin/mysqladmin -uroot -p shutdown -S mysql.sock
# the passward is 111
# remove the meta data stored in mysql
rm -rf ~/data

# stop the hadoop
stop-dfs.sh
stop-yarn.sh

# it's a must to clean the tmpssd file 
# rm -rf /tmpssd/*
# echo "You need to clean the tmpssd on other machines"