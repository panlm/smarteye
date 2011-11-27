#!/usr/local/groundwork/perl/bin/perl -w
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
# 26-Nov-2011 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $InRateWarn = -1;
my $InRateCrit = -1;
my $OutRateWarn = -1;
my $OutRateCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_i $opt_o $opt_d);
$opt_C = "yinjicomm";
$opt_P = 161;
$opt_V = "2c";
my $opt_n = 0;
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s
my $sleeptime = 50; # seconds

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_port";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
        "h"   => \$opt_h, "help"             => \$opt_h,
        "v"   => \$opt_v, "debug"            => \$opt_v,
        "f"   => \$opt_f, "performance"      => \$opt_f,
        "t=s" => \$TIMEOUT, "timeout=s"      => \$TIMEOUT,
        "S=s" => \$sleeptime, "sleeptime=s"  => \$sleeptime,
        "C=s" => \$opt_C, "Community=s"      => \$opt_C,
        "P=s" => \$opt_P, "port=s"           => \$opt_P,
        "V=s" => \$opt_V, "version=s"        => \$opt_V,
        "H=s" => \$opt_H, "host=s"           => \$opt_H,
        "i=s" => \$opt_i, "InRate=s"         => \$opt_i,
        "o=s" => \$opt_o, "OutRate=s"        => \$opt_o,
        "d=s" => \$opt_d, "device=s"         => \$opt_d,
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Need Hostname
if (!$opt_H) { die "-H <hostname> is required\n" }

# Need Device Address
if (!$opt_d) { die "-d <device-addr> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_v) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_f) { $perf = 1; }

# Options checking
if ($opt_i) { 
        ($InRateWarn, $InRateCrit) = split /:/, $opt_i;

        ($InRateWarn && $InRateCrit) || usage ("missing value -i <warn:crit>\n");

        ($InRateWarn =~ /^\d{1,3}$/ && $InRateWarn > 0 && $InRateWarn <= 100) &&
        ($InRateCrit =~ /^\d{1,3}$/ && $InRateCrit > 0 && $InRateCrit <= 100) ||
                usage("Invalid value: -i <warn:crit> (In Rate Percent): $opt_i\n");

        ($InRateCrit > $InRateWarn) || 
                usage("critical (-i $opt_i <warn:crit>) must be > warning\n");
}
print "InRateWarn:$InRateWarn; InRateCrit:$InRateCrit\n" if $debug;
if ($opt_o) { 
        ($OutRateWarn, $OutRateCrit) = split /:/, $opt_o;

        ($OutRateWarn && $OutRateCrit) || usage ("missing value -o <warn:crit>\n");

        ($OutRateWarn =~ /^\d{1,3}$/ && $OutRateWarn > 0 && $OutRateWarn <= 100) &&
        ($OutRateCrit =~ /^\d{1,3}$/ && $OutRateCrit > 0 && $OutRateCrit <= 100) ||
                usage("Outvalid value: -o <warn:crit> (Out Rate Percent): $opt_o\n");

        ($OutRateCrit > $OutRateWarn) || 
                usage("critical (-o $opt_o <warn:crit>) must be > warning\n");
}
print "OutRateWarn:$OutRateWarn; OutRateCrit:$OutRateCrit\n" if $debug;

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;

# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost   => $opt_d,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my ($string) = undef;
($string) = $snmp_session->bulkwalk(0,1,[
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.1']
]);
check_for_errors();

my $str1 = undef;
my $i = 0;
for ( $i = 0; $i <= $#$string; $i++ ) {
    if ( @$string[$i]->val =~ /$opt_H/ ) {
        printf "%s\n",@$string[$i]->val if $debug;
        $str1 = @$string[$i]->val;
        last;
    }
}

my $oid = "13";
for ( $i = 0; $i < length($str1); $i++ ) {
    $oid = $oid . "." . ord(substr($str1,$i,1));
}
printf "$oid\n" if $debug;

my ($tmp_in, $tmp_out) = undef;
# retrieve the data from the remote host
($tmp_in, $tmp_out) = $snmp_session->get([
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.4',$oid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.6',$oid]
]);

printf "in:%s\t out:%s\n",$tmp_in,$tmp_out if $debug;

# need to sleep to get delta
sleep $sleeptime;

my ($in, $out, $conn) = undef;
# retrieve the data from the remote host
($in, $out, $conn) = $snmp_session->get([
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.4',$oid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.6',$oid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.9',$oid]
]);

printf "in:%s\t out:%s\t conn:%s\n",$in,$out,$conn if $debug;

alarm (0); # Done with network

# deal wrap
if ($in < $tmp_in ) {
    $in = 4294967295 + $in +1;
}
if ($out < $tmp_out ) {
    $out = 4294967295 + $out +1;
}

# Calculate Here
my ($inbit, $outbit) = undef;
$inbit = ( $in - $tmp_in ) * 8 / $sleeptime ;
$outbit = ( $out - $tmp_out ) * 8 / $sleeptime ;

# Threshold checks
my $output = undef;

$output = $output . sprintf("In: %.2fbps ", $inbit);
$output = $output . sprintf("Out: %.2fbps ", $outbit);
$output = $output . sprintf("Connections: %d ", $conn);

# Main output
print "$output";

# Performance output
if ($perf) {;
        print " |";
        printf(" In=%.2f;;;;",$inbit);
        printf(" Out=%.2f;;;;",$outbit);
        printf(" Conn=%d;;;;",$conn);
}

print "\n";

# Plugin output
# $worst == $ERRORS{'OK'} ?  print "CPU OK @goodlist" : print "@badlist";

# Performance? 

if ($output =~ /Critical/) { exit $ERRORS {'CRITICAL'} }
if ($output =~ /Warning/)  { exit $ERRORS {'WARNING'}  }

exit (0); #OK

# Usage sub
sub print_usage () {
        print "Usage: $PROGNAME 
        [-h], --help
        [-V], --debug
        [-H], --host
        [-C], --Community <community>
        [-P], --port snmp_port (default 161)
        [-v], --version snmp_version (default 2c)
        [-n], --SwitchPort <switchport> (default 2)
        [-f] (output Nagios performance data)
        [-i], --InRate <warn:crit> percent
        [-o], --OutRate <warn:crit> percent
        \n";
}

# Help sub
sub print_help () {
        print_revision($PROGNAME,'$Revision$');
        print_usage();
}

sub check_for_errors {
        if ( $snmp_session->{ErrorNum} ) {
                print "UNKNOWN - error retrieving SNMP data: $snmp_session->{ErrorStr}\n";
                exit $ERRORS{UNKNOWN};
        }
}

