#!/bin/bash
# total files under a directory ?
# just level 1 sub-directory ?
# just files or files and sub-directory ?

if [ $# -ne 1 ]; then
    echo "$0 <dest_dir>"
    exit 9
fi

dir=$1

if [ ! -d $dir ]; then
    echo "$dir is not a directory"
    exit 9
fi

now=$( date +%s )
today=$( date --date 'today 00:00:00' +%s )
delta=$( echo "($now-$today)/60" |bc )

num=$( find $dir -type f -mmin -$delta |wc -l )

echo "there are ${num} files modified today in directory named \"${dir}\". | count=${num};;;; "
