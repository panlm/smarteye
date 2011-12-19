#!/bin/bash

if [ $# -ne 2 ]; then
    echo "$0 <hostname> <table_name>"
    exit 9
fi

hostname=$1
tablename=$2
libexec=/usr/local/groundwork/nagios/libexec
script=$libexec/check_mysql_query
socket=/usr/local/groundwork/mysql/tmp/mysql.sock
mysqluser=nagios
mysqlpass=nagios
sql="select data_free from information_schema.tables where table_name='$tablename'"

if [ ! -S $socket ]; then
    echo "mysql not running"
    exit 9
fi

if [ ! -x $script ]; then
    echo check_mysql_query not found.
    exit 9
fi

return=$($script -H $hostname -u $mysqluser -p $mysqlpass -s $socket -q "$sql")
echo $return |grep -q 'QUERY OK'
if [ $? -ne 0 ]; then
    echo $return
    exit 9
else
    frag=$(echo $return|awk '{print $NF}')
    echo "the fragment of table $tablename is $frag | frag=$frag;;;;"
fi


