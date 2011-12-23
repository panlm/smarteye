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
# 22-Dec-2010 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my $IOSentWarn = -1;
my $IOSentCrit = -1;
my $IOReceiveWarn = -1;
my $IOReceiveCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_s $opt_r);
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
$PROGNAME = "check_snmp_io";

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
        "s=s" => \$opt_s, "IOSent=s"         => \$opt_s,
        "r=s" => \$opt_r, "IOReceive=s"        => \$opt_r
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
if ($opt_s) { 
        ($IOSentWarn, $IOSentCrit) = split /:/, $opt_s;

        ($IOSentWarn && $IOSentCrit) || usage ("missing value -i <warn:crit>\n");

        ($IOSentWarn =~ /^\d{1,3}$/ && $IOSentWarn > 0 && $IOSentWarn <= 100) &&
        ($IOSentCrit =~ /^\d{1,3}$/ && $IOSentCrit > 0 && $IOSentCrit <= 100) ||
                usage("Invalid value: -s <warn:crit> (IO Sent): $opt_s\n");

        ($IOSentCrit > $IOSentWarn) || 
                usage("critical (-s $opt_s <warn:crit>) must be > warning\n");
}
print "IOSentWarn:$IOSentWarn; IOSentCrit:$IOSentCrit\n" if $debug;
if ($opt_r) { 
        ($IOReceiveWarn, $IOReceiveCrit) = split /:/, $opt_r;

        ($IOReceiveWarn && $IOReceiveCrit) || usage ("missing value -o <warn:crit>\n");

        ($IOReceiveWarn =~ /^\d{1,3}$/ && $IOReceiveWarn > 0 && $IOReceiveWarn <= 100) &&
        ($IOReceiveCrit =~ /^\d{1,3}$/ && $IOReceiveCrit > 0 && $IOReceiveCrit <= 100) ||
                usage("Outvalid value: -r <warn:crit> (IO Receive): $opt_r\n");

        ($IOReceiveCrit > $IOReceiveWarn) || 
                usage("critical (-r $opt_r <warn:crit>) must be > warning\n");
}
print "IOReceiveWarn:$IOReceiveWarn; IOReceiveCrit:$IOReceiveCrit\n" if $debug;

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

my ($last_check_time, $tmp_iorawsent, $tmp_iorawreceive) = undef;
if ( open(FILE,"$tmp_dir/$history_file_name") ) {;
    $last_check_time = <FILE>; chomp($last_check_time);
    $tmp_iorawsent = <FILE>;     chomp($tmp_iorawsent);
    $tmp_iorawreceive = <FILE>;    chomp($tmp_iorawreceive);
    close(FILE);
} else {
    # retrieve the data from the remote host
    $last_check_time = time();
    ($tmp_iorawsent, $tmp_iorawreceive) = $snmp_session->get([
        ['ssIORawSent',0],
        ['ssIORawReceived',0]
    ]);
    check_for_errors();

    # need to sleep to get delta
    sleep $sleeptime;

}

print "date\t iorawsent\t iorawreceive\n" if $debug;
print "$last_check_time\t $tmp_iorawsent\t $tmp_iorawreceive\n" if $debug;

my ($check_time, $iorawsent, $iorawreceive) = undef;
# retrieve the data from the remote host
$check_time = time();
($iorawsent, $iorawreceive) = $snmp_session->get([
    ['ssIORawSent',0],
    ['ssIORawReceived',0]
]);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$iorawsent\n";
    print FILE "$iorawreceive\n";
    close(FILE);
}

print "date\t iorawsent\t iorawreceive\n" if $debug;
print "$check_time\t $iorawsent\t $iorawreceive\n" if $debug;

alarm (0); # Done with network

# deal wrap
if ($iorawsent < $tmp_iorawsent ) {
    $iorawsent = 4294967295 + $iorawsent +1;
}
if ($iorawreceive < $tmp_iorawreceive ) {
    $iorawreceive = 4294967295 + $iorawreceive +1;
}

# Calculate Here
my ($iosentrate, $ioreceiverate) = undef;
$iosentrate = ( $iorawsent - $tmp_iorawsent ) / ( $check_time - $last_check_time ) ;
$ioreceiverate = ( $iorawreceive - $tmp_iorawreceive ) / ( $check_time - $last_check_time ) ;

print "iorawsent: $iosentrate\n" if $debug;
print "iorawreceive: $ioreceiverate\n" if $debug;

# Threshold checks
my $output = undef;

$output = $output . sprintf("IOSent: %.2f block/s ", $iosentrate);
$output = $output . sprintf("IOReceive: %.2f block/s ", $ioreceiverate);
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
        printf(" iosent=%.2f;;;;",$iosentrate);
        printf(" ioreceive=%.2f;;;;",$ioreceiverate);
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
        [-s], --IOSent <warn:crit>
        [-r], --IOReceive <warn:crit>
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

