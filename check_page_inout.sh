#!/bin/bash

if [ $# -ne 1 ]; then
    echo "$0 <time>"
    exit 9
fi

sec=$1

if [ ! -x /usr/bin/sar ]; then
    echo "sar can not executed"
    exit 9
fi

string=$(sar -B 1 $sec |awk '/^Average/ {print $2,$3}')
pgpgin=${string%% *}
pgpgout=${string##* }

echo "pagein/s=${pgpgin}KB pageout/s=${pgpgout}KB | pagein=${pgpgin};;;; pageout=${pgpgout};;;;"

