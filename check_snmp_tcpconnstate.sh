#!/bin/bash

if [ $# -ne 2 ]; then
    echo "usage: $0 hostname snmp-community-string"
    exit 99
fi

host=$1
comm=$2

#a=$(snmpwalk -v2c -c$comm $host .1.3.6.1.2.1.25.1.5.0 2>&1)
##if [ $? -ne 0 ]; then
#    echo "snmp get error"
#    echo $a
#fi
#
#num=$(echo $a |awk '{print $NF}')
#
#echo "USERS OK - $num users currently logged in |users=$num;;;"

#snmpwalk  -v2c -cyinjicomm localhost tcpConnState >/tmp/$$

snmpwalk  -v2c -c$comm $host tcpConnState |awk '{
sub(/\([0-9][0-9]*\)/,"",$NF)
a[$NF]+=1
}
END {
for(j in a)print j,a[j] >> "/var/tmp/awk.debug"
printf "TCP Connection State OK | closed=%d;;; listen=%d;;; synSent=%d;;; synReceived=%d;;; established=%d;;; finWait1=%d;;; finWait2=%d;;; closeWait=%d;;; lastAck=%d;;; closing=%d;;; timeWait=%d;;; deleteTCB=%d;;; \n",a["closed"],a["listen"],a["synSent"],a["synReceived"],a["established"],a["finWait1"],a["finWait2"],a["closeWait"],a["lastAck"],a["closing"],a["timeWait"],a["deleteTCB"]
}'

#established 244
#timeWait 192
#listen 40
#finWait1 2
#finWait2 2

