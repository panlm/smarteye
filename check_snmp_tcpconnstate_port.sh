#!/bin/bash
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this
# program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301, USA.
#
# Change Log
#----------------
# 1-Aug-2012 - stevenpan@gmail.com
#        port connection monitor
#
# 11-Jan-2012 - stevenpan@gmail.com
#        Initial revision
#

warn=0
crit=0

if [[ $# -ne 3 && $# -ne 5 ]]; then
    echo ""
    echo "usage: $0 hostname snmp-community-string port-number [warn] [crit]"
    echo ""
    exit 3
fi

host=$1
comm=$2
port=$3
if [ $# -eq 5 ]; then
    warn=$4
    crit=$5
    num=$(echo $warn$crit |tr -d 0-9 |wc -c)
    if [ $num -ne 1 ]; then
        echo "warn / crit error, is it number? (>1)"
        exit 3
    fi
    if [ $crit -le $warn ]; then
        echo "crit less warn"
        exit 3
    fi
fi

snmpwalk  -v2c -c$comm $host tcpConnState |awk -F '[. ]' '{
if ( $6 ~ /^'"$port"'$/ ) {
  sub(/\([0-9][0-9]*\)/,"",$NF)
  a[$NF]+=1
}
}
END {
#for(j in a)print j,a[j] >> "/var/tmp/awk.debug"
if ( '"$warn"' != 0 && '"$crit"' != 0 ) {
    if(a["established"]<'"$warn"') {
        state="OK"
        statenum="0"
    } else if (a["established"]>='"$crit"') {
        state="CRTICAL"
        statenum="2"
    } else {
        state="WARNING"
        statenum="1"
    }
} else {
    state="OK"
    statenum=0
}
printf "TCP Connection State is \"%s\", Established is %d | closed=%d;;; ",state,a["established"],a["closed"]
printf "listen=%d;;; ",a["listen"]
printf "synSent=%d;;; ",a["synSent"]
printf "synReceived=%d;;; ",a["synReceived"]
printf "established=%d;;; ",a["established"]
printf "finWait1=%d;;; ",a["finWait1"]
printf "finWait2=%d;;; ",a["finWait2"]
printf "closeWait=%d;;; ",a["closeWait"]
printf "lastAck=%d;;; ",a["lastAck"]
printf "closing=%d;;; ",a["closing"]
printf "timeWait=%d;;; ",a["timeWait"]
printf "deleteTCB=%d;;; \n",a["deleteTCB"]

exit (statenum)

}'

