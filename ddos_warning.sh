#!/bin/sh
pps=`cat /var/tmp/inpktps_172.29.251.12_6`
inpktps=${pps%.*}
if [ $inpktps -ge 20000 ]
then 
	/usr/bin/expect -f /pub/svn/projects/smarteye-plugin/trunk/get_a10_packet.exp >/var/tmp/temp_file.txt
	a=`awk '{if($1~/^@/ && $2=="i(" && $3=="6,1000," ) print $8}' /var/tmp/temp_file.txt |sort |uniq -c |sort -nr |sed -n '1p' |awk '{print $1}'`
	attacked_ip=`awk '{if($1~/^@/ && $2=="i(" && $3=="6,1000," ) print $8}' /var/tmp/temp_file.txt |sort |uniq -c |sort -nr |sed -n '1p' |awk '{print $2}'`
	b=`awk '{if($1~/^@/ && $2=="i(" && $3=="6,1000," ) print $0}' /var/tmp/temp_file.txt |wc -l`
	c=`expr $a \* 100`
	d=`expr $c / $b`

		#echo d=$d%
		#echo attacked_ip=$attacked_ip
		echo -e "attacked_ip=$attacked_ip\nthis_ip_count=$a\ntotal_count=$b\npercent=$d%" |mail -s "attack_info" sorghum2009@gmail.com,panlm@yinji.com.cn -- -f gaols@zijian.com.cn

fi
