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
# 22-Dec-2011 - stevenpan@gmail.com
#        Initial revision
#
# 28-Dec-2011 - stevenpan@gmail.com
#        add snmp v1 snmp_session->gettable support
#
use strict;

my $CPUWarn = -1;
my $CPUCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use Data::Dumper;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_c $opt_d);
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
$PROGNAME = "check_snmp_processorload";

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
        "c=s" => \$opt_c, "CPU=s"            => \$opt_c,
        "d" => \$opt_d, "detail"            => \$opt_d,
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
if ($opt_c) { 
        ($CPUWarn, $CPUCrit) = split /:/, $opt_c;

        ($CPUWarn && $CPUCrit) || usage ("missing value -i <warn:crit>\n");

        ($CPUWarn =~ /^\d{1,3}$/ && $CPUWarn > 0 && $CPUWarn <= 100) &&
        ($CPUCrit =~ /^\d{1,3}$/ && $CPUCrit > 0 && $CPUCrit <= 100) ||
                usage("Invalid value: -i <warn:crit> (Swap In): $opt_c\n");

        ($CPUCrit > $CPUWarn) || 
                usage("critical (-i $opt_c <warn:crit>) must be > warning\n");
}
print "CPUWarn:$CPUWarn; CPUCrit:$CPUCrit\n" if $debug;

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;
print "snmp_ver:$opt_V\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_H,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my $cpu = undef;
my $arr = undef;
my ($key, $value, $c) = undef;
if ( $opt_V eq "2c" ) {
    ($arr) = $snmp_session->bulkwalk(0,1,[
        ['hrProcessorLoad']
    ]);
    check_for_errors();
    for ( my $i = 0; $i <= $#$arr; $i++ ) {
        @$cpu[$i] = scalar(@$arr[$i]->val);
    }
} else {
    ($arr) = $snmp_session->gettable('.1.3.6.1.2.1.25.3.3');
    check_for_errors();
    my $i = 0;
    for $c (sort keys %$arr ) {
        #print "$c: \n" if $debug;
        while(($key,$value) = each %{@$arr{$c}}) {
            #print "$key => $value \n" if $debug;
            if ( $key eq "hrProcessorLoad" ) {
                @$cpu[$i] = $value ;
                print "set value: @$cpu[$i]\n";
                $i++;
            }
        }
    }
}
#print Dumper($cpu);
#print "@$cpu[0] \t @$cpu[1]\n";

# Calculate Here
my $avg = 0;

for ( my $i = 0; $i <= $#$cpu; $i++ ) {
    $avg = $avg + @$cpu[$i];
    printf "%d\t",@$cpu[$i] if $debug;
}
print "\n" if $debug;

$avg = $avg / ( $#$cpu + 1 );
printf "Average: $avg\n" if $debug;

alarm (0); # Done with network

# Threshold checks
my $output = "";

$output = $output . sprintf("ProcessorLoad: %.2f KB/s ", $avg);
if ($CPUCrit > 0) {
        ($avg > $CPUCrit) ? ($output = $output . "(Critical) ") :
                ($avg > $CPUWarn) ? ($output = $output . "(Warning) ") : 
                        ($output = $output."(OK) ");
} else {
        $output=$output."(OK) ";
}

# Main output
print "$output";

# Performance output
if ($perf) {;
    print " |";
    if ( ! $opt_d ) {
        if ($CPUCrit < 0) {
            printf(" ProcessorLoad=%.2f;;;;", $avg)
        } else {
            printf(" ProcessorLoad=%.2f;%d;%d;;", $avg,$CPUWarn,$CPUCrit)
        }
    } else {
        for ( my $i = 0; $i <= $#$cpu; $i++ ) {
            printf(" p%d=%d;;;;",$i,@$cpu[$i]);
        }
    }
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
        [-c], --CPU <warn:crit>
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

