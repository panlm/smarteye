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
# 23-Dec-2010 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my $LoadWarn = -1;
my $LoadCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_l);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_io";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
        "h"   => \$opt_h, "help"             => \$opt_h,
        "v"   => \$opt_v, "debug"            => \$opt_v,
        "f"   => \$opt_f, "performance"      => \$opt_f,
        "T=s" => \$TIMEOUT, "timeout=s"      => \$TIMEOUT,
        "C=s" => \$opt_C, "Community=s"      => \$opt_C,
        "P=s" => \$opt_P, "port=s"           => \$opt_P,
        "V=s" => \$opt_V, "version=s"        => \$opt_V,
        "H=s" => \$opt_H, "host=s"           => \$opt_H,
        "l=s" => \$opt_l, "load=s"           => \$opt_l
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
if ($opt_l) { 
        ($LoadWarn, $LoadCrit) = split /:/, $opt_l;

        ($LoadWarn && $LoadCrit) || usage ("missing value -i <warn:crit>\n");

        ($LoadWarn =~ /^\d{1,3}$/ && $LoadWarn > 0 && $LoadWarn <= 100) &&
        ($LoadCrit =~ /^\d{1,3}$/ && $LoadCrit > 0 && $LoadCrit <= 100) ||
                usage("Invalid value: -s <warn:crit> (IO Sent): $opt_l\n");

        ($LoadCrit > $LoadWarn) || 
                usage("critical (-s $opt_l <warn:crit>) must be > warning\n");
}
print "LoadWarn:$LoadWarn; LoadCrit:$LoadCrit\n" if $debug;

print "timeout:$TIMEOUT\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_H,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my ($load1, $load5, $load15) = undef;
# retrieve the data from the remote host
($load1, $load5, $load15) = $snmp_session->get([
    ['laLoad',1],
    ['laLoad',2],
    ['laLoad',3]
]);
check_for_errors();
if ( $load1 =~ /NOSUCHOBJECT/ ) { exit $ERRORS{'UNKNOWN'} };

print "load1\t load5\t load15\n" if $debug;
print "$load1\t $load5\t $load15\n" if $debug;

alarm (0); # Done with network

# Threshold checks
my $output = undef;

$output = $output . sprintf("Load1: %.2f ", $load1);
$output = $output . sprintf("Load5: %.2f ", $load5);
$output = $output . sprintf("Load15: %.2f ", $load15);
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
        printf(" load1=%.2f;;;;",$load1);
        printf(" load5=%.2f;;;;",$load5);
        printf(" load15=%.2f;;;;",$load15);
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
        [-C], --community <community>
        [-P], --port <snmp_port>        (default is $opt_P)
        [-V], --version <snmp_version>  (default is $opt_V)
        [-H], --host <ip>
        [-l], --load <warn:crit>
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

