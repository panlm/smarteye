#!/bin/bash

if [ $# -ne 3 ]; then
    echo "usage:"
    echo "$0 <hostname> <snmp_community> <oid>"
    exit 9
fi

#/usr/local/groundwork/nagios/libexec/check_snmp -H $1 -C $2 -o "$3" |awk '{print $4,$5,$6}' |read a b c
##echo "SNMP OK - "$a $b $c" | "42.81 0.98 431.51
#printf "SNMP OK - %s %s %s | tps=%s readKB=%s writeKB=%s\n" $a $b $c $a $b $c

result=$(/usr/local/groundwork/nagios/libexec/check_snmp -H $1 -C $2 -o "$3" |awk -F'[-|]' '{print $2}')

n=1
for i in $result ; do
    str="$str var$n=$i;;;;"
#    eval var$n=$i
    n=$((n+1))
done

echo "SNMP OK - $result | $str"

#(cpu: ALL) user: 15.77% (OK) nice: 0.00% (OK) sys: 1.07% (OK) idle: 83.17% (OK)  | user=15.77%;;;; nice=0.00%;;;; sys=1.07%;;;; idle=83.17%;;;;
