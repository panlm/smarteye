#!/bin/bash

#time=$(date --date "1 minute ago" +%Y%m%d%H%M%S)
#echo -e "$time \c" >>/tmp/iostat-ext.hist
#cat /tmp/iostat-ext >>/tmp/iostat-ext.hist
#  |tee /tmp/io/$time

disks="dm-0 dm-1"
#disks="dm-0 dm-1 dm-2 dm-3 dm-4"

if [ ! -x /usr/bin/iostat ]; then
    echo "please install sysstat first"
    exit 9
fi

/usr/bin/iostat -kx $disks -t 55 2 >/tmp/iostat.$$

sn=1
for disk in $disks ; do
    out=/tmp/iostat.$sn
    tmpout=/tmp/iostat.$sn.tmp

    cat /tmp/iostat.$$ |grep "^$disk" |tail -n 1 \
      |awk '{print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12}' > $tmpout

    cat $tmpout |xargs -n 1 |sed -n '2,$'p |awk '{if($0>1000000000)print "error"}' |grep -q error
    if [ $? -ne 0 ]; then
        mv -f $tmpout $out
    fi

    sn=$((sn+1))
done

rm -f /tmp/iostat.$$

