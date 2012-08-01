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
# 11-Jan-2012 - stevenpan@gmail.com
#        Initial revision
#

if [ $# -ne 3 ]; then
    echo "usage: $0 hostname snmp-community-string port-number"
    exit 3
fi

host=$1
comm=$2
port=$3

snmpwalk  -v2c -c$comm $host tcpConnState |awk -F '[. ]' '{
if ( $6 ~ /'"$port"'/ ) {
  sub(/\([0-9][0-9]*\)/,"",$NF)
  a[$NF]+=1
}
}
END {
#for(j in a)print j,a[j] >> "/var/tmp/awk.debug"
printf "TCP Connection State OK, Established is %d | closed=%d;;; ",a["established"],a["closed"]
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
}'

