#!/bin/ksh

if [ $# -ne 3 ]; then
  echo "usage:"
  echo "$0 <hostname> <snmp_community> <oid>"
  exit 9
fi

/usr/local/groundwork/nagios/libexec/check_snmp -H $1 -C $2 -o "$3" |awk '{print $4,$5,$6}' |read a b c
#echo "SNMP OK - "$a $b $c" | "42.81 0.98 431.51
printf "SNMP OK - %s %s %s | tps=%s readKB=%s writeKB=%s\n" $a $b $c $a $b $c

