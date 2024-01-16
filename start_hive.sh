start hive service
schematool -initSchema -dbType mysql -vebin/mysqld_safe --defaults-file=my.cnf
hive --service metastore &