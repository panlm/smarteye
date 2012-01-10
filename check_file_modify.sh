#!/bin/bash


usage()
{
	echo "usage : ./check_file_modify.sh filename warningValue(s) criticalValue(s)"
	echo "example : ./check_file_modify.sh check_file_modify.sh 30 50"
	exit 1;
}

if [ $# -ne 3 ]; then
	echo "parameter error"
	usage
fi

FILE_PATH="$1"
WTIME="$2"
CTIME="$3"

if [ ! -f $FILE_PATH ]; then
	echo "file $FILE_PATH not found"	
	usage
fi

warning=`echo $2 | grep '[0-9]'`

if [ -z "$warning" ] || [ "$warning" -le '0' ]; then
	echo "Warning value must be a positive integer"
	usage
fi

critical=`echo $3 | grep '[0-9]'`
if [ -z "$critical" ] || [ "$critical" -le '0' ] || [ "$critical" -lt "$warning" ]; then
	echo "critical value must be a positive integer and critical value must greater than warning value"
        usage
fi

MY_TIME=`stat $FILE_PATH | grep Modify | awk '{print $2" "$3}'`

STIME=$(date +'%s')
FTIME=$(date -d "$MY_TIME" +'%s')
PTIME=(`expr "$STIME" - "$FTIME"`)

if [ "$PTIME" -gt "$CTIME" ]; then
	echo "CRITICAL - modify file $1 is critical , time is $PTIME(s) | time=$PTIME;$2;$3;;"
	exit 0
fi

if [ "$PTIME" -gt "$WTIME" ]; then
        echo "WARNING - modify file $1 is warning , time is $PTIME(s) | time=$PTIME;$2;$3;;"
	exit 0
fi

echo "OK - modify file $1 is ok , time is $PTIME(s) | time=$PTIME;$2;$3;;"

exit
