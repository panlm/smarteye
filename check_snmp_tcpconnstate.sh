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

if [ $# -ne 2 ]; then
    echo "usage: $0 hostname snmp-community-string"
    exit 3
fi

host=$1
comm=$2

snmpwalk  -v2c -c$comm $host tcpConnState |awk '{
sub(/\([0-9][0-9]*\)/,"",$NF)
a[$NF]+=1
}
END {
#for(j in a)print j,a[j] >> "/var/tmp/awk.debug"
printf "TCP Connection State OK | closed=%d;;; listen=%d;;; synSent=%d;;; synReceived=%d;;; established=%d;;; finWait1=%d;;; finWait2=%d;;; closeWait=%d;;; lastAck=%d;;; closing=%d;;; timeWait=%d;;; deleteTCB=%d;;; \n",a["closed"],a["listen"],a["synSent"],a["synReceived"],a["established"],a["finWait1"],a["finWait2"],a["closeWait"],a["lastAck"],a["closing"],a["timeWait"],a["deleteTCB"]
}'

