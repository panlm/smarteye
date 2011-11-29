#!/bin/bash

if [ $# -ne 2 ]; then
    echo "usage: $0 hostname snmp-community-string"
    exit 99
fi

host=$1
comm=$2

a=$(snmpwalk -v2c -c$comm $host .1.3.6.1.2.1.25.1.5.0 2>&1)
if [ $? -ne 0 ]; then
    echo "snmp get error"
    echo $a
fi

num=$(echo $a |awk '{print $NF}')

echo "USERS OK - $num users currently logged in |users=$num;;;"
