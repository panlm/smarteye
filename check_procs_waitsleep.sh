#!/bin/bash
# vmstat 5 2
# Procs
# r: The number of processes waiting for run time.
# b: The number of processes in uninterruptible sleep.

if [ $# -ne 1 ]; then
    echo "$0 <delay_sec>"
    exit 9
fi

sec=$1

tmpfile=/tmp/check_procs_waitsleep.sh.$$
/usr/bin/vmstat $sec 2 >$tmpfile
r=$( cat $tmpfile |tail -n 1 |awk '{print $1}' )
b=$( cat $tmpfile |tail -n 1 |awk '{print $2}' )

rm -f $tmpfile

echo "${r} processes are waiting for run and ${b} processes are sleeping | waiting=${r};;;; sleeping=${b};;;;"

