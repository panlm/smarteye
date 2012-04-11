#!/bin/bash

if [ $# -ne 2 ]; then
    echo "usage: $0 hostname snmp-community-string"
    exit 99
fi

host=$1
comm=$2
out=/var/tmp/check_uptime.$host.last

if [ ! -f $out ]; then
    echo 0 > $out
fi

a=$(snmpwalk -v2c -c$comm $host .1.3.6.1.2.1.1.3.0 2>&1)
if [ $? -ne 0 ]; then
    echo "snmp get error"
    echo $a
    exit 99
fi

oldtime=$(cat $out)
time=$(echo $a |awk -F'[()]' '{print $2}')

echo $time >$out
echo $a |awk -F'[()]' '{print "uptime:",$3}'

if [ $time -gt $oldtime ]; then
    exit 0
else
    exit 2
fi
