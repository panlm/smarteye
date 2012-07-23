#!/bin/bash

if [ $# -ne 1 ]; then
    echo "usage: $0 [cpu|mem]"
    exit 99
fi

case $1 in
    cpu) col=7 ;;
    mem) col=6 ;;
    *)   echo "parameter error"
         exit 99
    ;;
esac

/bin/ps axwo 'stat uid pid ppid vsz rss pcpu comm args' >/tmp/$$

cat /tmp/$$ |sort -k${col}rn |head -n 3 |awk '{printf "%s/%s\n",$3,$8}' |xargs

#rm -f /tmp/$$




