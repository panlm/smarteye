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

num=$( ls $dir |wc -l )

echo "there are ${num} files in ${dir}. | count=${num};;;; "
