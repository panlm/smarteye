#!/bin/bash

#ips=(`ifconfig | grep 'inet addr' | awk -F ':' '{print $2}' | grep --color -o '\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}'`)

ips=(`/sbin/ifconfig -a | sed -n '/^[^ \t]/{N;s/\(^[^ ]*\).*addr:\([^ ]*\).*/\1\t\2/p}'|grep -v '127.0.0.1'`)


message=""
for ((i=0;i<${#ips[@]};i++));
do
	message="$message ${ips[i]}"
	
done

echo "OK - RemoterServer is ok , ip :$message  | status=0;;;;"

exit 0



