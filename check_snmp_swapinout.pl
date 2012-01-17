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
# 22-Dec-2012 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my $SwapInWarn = -1;
my $SwapInCrit = -1;
my $SwapOutWarn = -1;
my $SwapOutCrit = -1;

my $debug = 0;
my $perf = 0;

#sysUpTimeInstance
my $uptimeoid = ".1.3.6.1.2.1.1.3.0";

use SNMP;
use Getopt::Long;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_i $opt_o);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s
my $sleeptime = 10; # seconds

sub print_help ();
sub print_usage ();

my $tmp_dir = "/var/tmp";
$PROGNAME = "check_snmp_swapinout";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
        "h"   => \$opt_h, "help"             => \$opt_h,
        "v"   => \$opt_v, "debug"            => \$opt_v,
        "f"   => \$opt_f, "performance"      => \$opt_f,
        "T=s" => \$TIMEOUT, "timeout=s"      => \$TIMEOUT,
        "S=s" => \$sleeptime, "sleeptime=s"  => \$sleeptime,
        "C=s" => \$opt_C, "Community=s"      => \$opt_C,
        "P=s" => \$opt_P, "port=s"           => \$opt_P,
        "V=s" => \$opt_V, "version=s"        => \$opt_V,
        "H=s" => \$opt_H, "host=s"           => \$opt_H,
        "i=s" => \$opt_i, "InRate=s"         => \$opt_i,
        "o=s" => \$opt_o, "OutRate=s"        => \$opt_o
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Need Hostname
if (!$opt_H) { die "-H <hostname> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_v) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_f) { $perf = 1; }

# Options checking
if ($opt_i) { 
        ($SwapInWarn, $SwapInCrit) = split /:/, $opt_i;

        ($SwapInWarn && $SwapInCrit) || usage ("missing value -i <warn:crit>\n");

        ($SwapInWarn =~ /^\d{1,3}$/ && $SwapInWarn > 0 && $SwapInWarn <= 100) &&
        ($SwapInCrit =~ /^\d{1,3}$/ && $SwapInCrit > 0 && $SwapInCrit <= 100) ||
                usage("Invalid value: -i <warn:crit> (Swap In): $opt_i\n");

        ($SwapInCrit > $SwapInWarn) || 
                usage("critical (-i $opt_i <warn:crit>) must be > warning\n");
}
print "SwapInWarn:$SwapInWarn; SwapInCrit:$SwapInCrit\n" if $debug;
if ($opt_o) { 
        ($SwapOutWarn, $SwapOutCrit) = split /:/, $opt_o;

        ($SwapOutWarn && $SwapOutCrit) || usage ("missing value -o <warn:crit>\n");

        ($SwapOutWarn =~ /^\d{1,3}$/ && $SwapOutWarn > 0 && $SwapOutWarn <= 100) &&
        ($SwapOutCrit =~ /^\d{1,3}$/ && $SwapOutCrit > 0 && $SwapOutCrit <= 100) ||
                usage("Outvalid value: -o <warn:crit> (Swap Out): $opt_o\n");

        ($SwapOutCrit > $SwapOutWarn) || 
                usage("critical (-o $opt_o <warn:crit>) must be > warning\n");
}
print "SwapOutWarn:$SwapOutWarn; SwapOutCrit:$SwapOutCrit\n" if $debug;

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_H,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my $history_file_name = $PROGNAME . "_" . $opt_H ;
print "$tmp_dir/$history_file_name\n" if $debug;

my ($last_check_time, $tmp_swapin, $tmp_swapout, $tmp_rawswapin, $tmp_rawswapout) = undef;
if ( open(FILE,"$tmp_dir/$history_file_name") ) {;
    $last_check_time = <FILE>; chomp($last_check_time);
    $tmp_swapin = <FILE>;          chomp($tmp_swapin);
    $tmp_swapout = <FILE>;         chomp($tmp_swapout);
    $tmp_rawswapin = <FILE>;     chomp($tmp_rawswapin);
    $tmp_rawswapout = <FILE>;    chomp($tmp_rawswapout);
    close(FILE);
} else {
    ($last_check_time, $tmp_swapin, $tmp_swapout, $tmp_rawswapin, $tmp_rawswapout) = $snmp_session->get([
        [$uptimeoid],
        ['ssSwapIn',0],
        ['ssSwapOut',0],
        ['ssRawSwapIn',0],
        ['ssRawSwapOut',0]
    ]);
    check_for_errors();

    # need to sleep to get delta
    sleep $sleeptime;
}

print "date\t swapin\t swapout\t rawswapin\t rawswapout\n" if $debug;
print "$last_check_time\t $tmp_swapin\t $tmp_swapout\t $tmp_rawswapin\t $tmp_rawswapout\n" if $debug;

my ($check_time, $swapin, $swapout, $rawswapin, $rawswapout) = undef;
($check_time, $swapin, $swapout, $rawswapin, $rawswapout) = $snmp_session->get([
    [$uptimeoid],
    ['ssSwapIn',0],
    ['ssSwapOut',0],
    ['ssRawSwapIn',0],
    ['ssRawSwapOut',0]
]);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$swapin\n";
    print FILE "$swapout\n";
    print FILE "$rawswapin\n";
    print FILE "$rawswapout\n";
    close(FILE);
}

print "date\t swapin\t swapout\t rawswapin\t rawswapout\n" if $debug;
print "$check_time\t $swapin\t $swapout\t $rawswapin\t $rawswapout\n" if $debug;

alarm (0); # Done with network

# deal reboot
if ( $last_check_time > $check_time ) {
    exit (0);
}

# deal wrap
if ( $rawswapin < $tmp_rawswapin   ) { $rawswapin = 4294967295 + $rawswapin +1;   }
if ( $rawswapout < $tmp_rawswapout ) { $rawswapout = 4294967295 + $rawswapout +1; }

# Calculate Here
my ($delta, $swapinrate, $swapoutrate) = undef;
$delta = ( $check_time - $last_check_time ) / 100;
$swapinrate = ( $rawswapin - $tmp_rawswapin ) / $delta ;
$swapoutrate = ( $rawswapout - $tmp_rawswapout ) / $delta ;

print "swapin: $swapin\n" if $debug;
print "swapout: $swapout\n" if $debug;
print "rawswapin: $swapinrate\n" if $debug;
print "rawswapout: $swapoutrate\n" if $debug;

# Threshold checks
my $output = undef;

$output = $output . sprintf("SwapIn: %.2f KB/s ", $swapin);
$output = $output . sprintf("SwapOut: %.2f KB/s ", $swapout);
$output = $output . sprintf("SwapIn: %.2f blocks/s ", $swapinrate);
$output = $output . sprintf("SwapOut: %.2f blocks/s ", $swapoutrate);
#$output = $output . sprintf("InRate: %.2f%% ", $inrate);
#if ($InRateCrit > 0) {
#        ($inrate > $InRateCrit) ? ($output = $output . "(Critical) ") :
#                ($inrate > $InRateWarn) ? ($output = $output . "(Warning) ") : 
#                        ($output = $output."(OK) ");
#} else {
#        $output=$output."(OK) ";
#}
#$output = $output . sprintf("OutRate: %.2f%% ", $outrate);
#if ($OutRateCrit > 0) {
#        ($outrate > $OutRateCrit) ? ($output = $output . "(Critical) ") :
#                ($outrate > $OutRateWarn) ? ($output = $output . "(Warning) ") : 
#                        ($output = $output . "(OK) ");
#} else {
#        $output=$output."(OK) ";
#}

# Main output
print "$output";

# Performance output
if ($perf) {;
        print " |";
        printf(" swapin=%.2f;;;;",$swapin);
        printf(" swapout=%.2f;;;;",$swapout);
        printf(" swapinblock=%.2f;;;;",$swapinrate);
        printf(" swapoutblock=%.2f;;;;",$swapoutrate);
#        if ($InRateCrit < 0) { printf(" InRate=%.2f;;;;", $inrate) }
#        else { printf(" InRate=%.2f;%d;%d;;", $inrate,$InRateWarn,$InRateCrit) }
#        if ($OutRateCrit < 0) { printf(" OutRate=%.2f;;;;", $outrate) }
#        else { printf(" OutRate=%.2f;%d;%d;;", $outrate,$OutRateWarn,$OutRateCrit) }
}

print "\n";

if ($output =~ /Critical/) { exit $ERRORS {'CRITICAL'} }
if ($output =~ /Warning/)  { exit $ERRORS {'WARNING'}  }

exit (0); #OK

# Usage sub
sub print_usage () {
    print "Usage: $PROGNAME 
        [-h], --help
        [-v], --debug
        [-f], --performance             (output Nagios performance data)
        [-T], --timeout <seconds>       (default is $TIMEOUT)
        [-S], --sleeptime <seconds>     (default is $sleeptime)
        [-C], --community <community>
        [-P], --port <snmp_port>        (default is $opt_P)
        [-V], --version <snmp_version>  (default is $opt_V)
        [-H], --host <ip>
        [-i], --SwapIn <warn:crit>
        [-o], --SwapOut <warn:crit>
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

