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
#	Initial revision
#
use strict;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $connwarn = -1;
my $conncrit = -1;

my $debug = 0;
my $perf = 0;

#sysUpTimeInstance
my $uptimeoid = ".1.3.6.1.2.1.1.3.0";

use SNMP;
use Getopt::Long;
use vars qw($opt_C $opt_O $opt_V $opt_D $opt_p $opt_h $opt_H $opt_c);
$opt_C = "public";
$opt_O = 161;
$opt_V = "2c";
# Watch out for this: snmpd updates every 5 secs by default
my $sleeptime = 10; # seconds
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

my $tmp_dir = "/var/tmp";
$PROGNAME = "check_snmp_conn";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"C=s" => \$opt_C, "community=s"	=> \$opt_C,
	"O"   => \$opt_O, "snmpport" => \$opt_O,
	"V"   => \$opt_V, "snmpversion"	=> \$opt_V,
	"D"   => \$opt_D, "debug"		=> \$opt_D,
	"p"   => \$opt_p, "performance"	=> \$opt_p,
	"S=s" => \$sleeptime, "sleeptime=s"	=> \$sleeptime,
	"t=s"   => \$TIMEOUT, "timeout=s"	=> \$TIMEOUT,
	"H=s" => \$opt_H, "hostname=s"		=> \$opt_H,
	"c=s" => \$opt_c, "conn=s"		=> \$opt_c,
	"h"   => \$opt_h, "help"		=> \$opt_h
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

# Need host name
if (!$opt_H) { die "-H <hostname> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_D) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_p) { $perf = 1; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Options checking
if ($opt_c) { 
	($connwarn, $conncrit) = split /:/, $opt_c;

	($connwarn && $conncrit) || usage ("missing value -c <warn:crit>\n");

	($conncrit > $connwarn) || 
		usage("connections (-c $opt_c <warn:crit>) must be > warning\n");
}

# Read /proc/stat values.  The first "cpu " line has aggregate values if
# the system is SMP, otherwise, just get the requested CPU

# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_O,
    Version	=> $opt_V
);

my $history_file_name = $PROGNAME . "_" . $opt_H ;
print "$tmp_dir/$history_file_name\n" if $debug;

my ($last_check_time, $tmp_tcpMaxConn, $tmp_tcpActiveOpens, $tmp_tcpPassiveOpens, $tmp_tcpAttemptFails, $tmp_tcpEstabResets, $tmp_tcpCurrEstab) = undef;
if ( open(FILE,"$tmp_dir/$history_file_name") ) {;
    $last_check_time = <FILE>;      chomp($last_check_time);
    $tmp_tcpMaxConn = <FILE>;       chomp($tmp_tcpMaxConn);
    $tmp_tcpActiveOpens = <FILE>;   chomp($tmp_tcpActiveOpens);
    $tmp_tcpPassiveOpens = <FILE>;  chomp($tmp_tcpPassiveOpens);
    $tmp_tcpAttemptFails = <FILE>;  chomp($tmp_tcpAttemptFails);
    $tmp_tcpEstabResets = <FILE>;   chomp($tmp_tcpEstabResets);
    $tmp_tcpCurrEstab = <FILE>;     chomp($tmp_tcpCurrEstab);
    close(FILE);
} else {
    ($last_check_time, $tmp_tcpMaxConn, $tmp_tcpActiveOpens, $tmp_tcpPassiveOpens, $tmp_tcpAttemptFails, $tmp_tcpEstabResets, $tmp_tcpCurrEstab) = $snmp_session->get([
        [$uptimeoid],
        ['tcpMaxConn',0],
        ['tcpActiveOpens',0],
        ['tcpPassiveOpens',0],
        ['tcpAttemptFails',0],
        ['tcpEstabResets',0],
        ['tcpCurrEstab',0]
    ]);
    check_for_errors();
    sleep $sleeptime;
}

printf "conn: $tmp_tcpCurrEstab\n" if $debug;
printf "tcpMaxConn:$tmp_tcpMaxConn, tcpActiveOpens:$tmp_tcpActiveOpens, tcpPassiveOpens:$tmp_tcpPassiveOpens, tcpAttemptFails:$tmp_tcpAttemptFails, tcpEstabResets:$tmp_tcpEstabResets, tcpCurrEstab:$tmp_tcpCurrEstab\n" if $debug;

my ($check_time, $tcpMaxConn, $tcpActiveOpens, $tcpPassiveOpens, $tcpAttemptFails, $tcpEstabResets, $tcpCurrEstab) = undef;
($check_time, $tcpMaxConn, $tcpActiveOpens, $tcpPassiveOpens, $tcpAttemptFails, $tcpEstabResets, $tcpCurrEstab) = $snmp_session->get([
    [$uptimeoid],
    ['tcpMaxConn',0],
    ['tcpActiveOpens',0],
    ['tcpPassiveOpens',0],
    ['tcpAttemptFails',0],
    ['tcpEstabResets',0],
    ['tcpCurrEstab',0]
]);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$tcpMaxConn\n";
    print FILE "$tcpActiveOpens\n";
    print FILE "$tcpPassiveOpens\n";
    print FILE "$tcpAttemptFails\n";
    print FILE "$tcpEstabResets\n";
    print FILE "$tcpCurrEstab\n";
    close(FILE);
}

printf "conn: $tcpCurrEstab\n" if $debug;
printf "tcpMaxConn:$tcpMaxConn, tcpActiveOpens:$tcpActiveOpens, tcpPassiveOpens:$tcpPassiveOpens, tcpAttemptFails:$tcpAttemptFails, tcpEstabResets:$tcpEstabResets, tcpCurrEstab:$tcpCurrEstab\n" if $debug;

alarm (0); # Done with network

# deal reboot
if ( $last_check_time > $check_time ) {
    exit (0);
}

# deal wrap
if ( $tcpActiveOpens  < $tmp_tcpActiveOpens  ) { $tcpActiveOpens  = 4294967295 + $tcpActiveOpens +1; }
if ( $tcpPassiveOpens < $tmp_tcpPassiveOpens ) { $tcpPassiveOpens = 4294967295 + $tcpPassiveOpens +1; }
if ( $tcpAttemptFails < $tmp_tcpAttemptFails ) { $tcpAttemptFails = 4294967295 + $tcpAttemptFails +1; }
if ( $tcpEstabResets  < $tmp_tcpEstabResets  ) { $tcpEstabResets  = 4294967295 + $tcpEstabResets +1; }

# Calculate Here
my ($delta, $tcpActiveOpensRate, $tcpPassiveOpensRate, $tcpAttemptFailsRate, $tcpEstabResetsRate) = undef;
$delta = ($check_time - $last_check_time) / 100;
$tcpActiveOpensRate  = ($tcpActiveOpens  - $tmp_tcpActiveOpens)  / $delta;
$tcpPassiveOpensRate = ($tcpPassiveOpens - $tmp_tcpPassiveOpens) / $delta;
$tcpAttemptFailsRate = ($tcpAttemptFails - $tmp_tcpAttemptFails) / $delta;
$tcpEstabResetsRate  = ($tcpEstabResets  - $tmp_tcpEstabResets)  / $delta;

printf "tcpActiveOpensRate:$tcpActiveOpensRate, tcpPassiveOpensRate:$tcpPassiveOpensRate, tcpAttemptFailsRate:$tcpAttemptFailsRate, tcpEstabResetsRate:$tcpEstabResetsRate\n" if $debug;

# Threshold checks
my $out = undef;
$out = $out . sprintf("conn: %d ", $tcpCurrEstab);
if ($conncrit > 0) {
    ($tcpCurrEstab > $conncrit) ? ($out = $out . "(Critical) ") :
        ($tcpCurrEstab > $connwarn) ? ($out=$out . "(Warning) ") : 
            ($out=$out."(OK) ");
} else {
    $out=$out."(OK) ";
}
$out = $out . sprintf("tcpMaxConn: %.2f ",        $tcpMaxConn);
$out = $out . sprintf("tcpActiveOpensRate: %.2f ",  $tcpActiveOpensRate);
$out = $out . sprintf("tcpPassiveOpensRate: %.2f ", $tcpPassiveOpensRate);
$out = $out . sprintf("tcpAttemptFailsRate: %.2f ", $tcpAttemptFailsRate);
$out = $out . sprintf("tcpEstabResetsRate: %.2f ",  $tcpEstabResetsRate);

# Main output
print "$out";

# Performance output
if ($perf) {;
    print " |";

    if ($conncrit < 0) { printf(" conn=%d;;;;", $tcpCurrEstab) }
    else { printf(" conn=%d;%d;%d;;", $tcpCurrEstab,$connwarn,$conncrit) }

    printf(" tcpMaxConn=%.2f;;;;",          $tcpMaxConn);
    printf(" tcpActiveOpensRate=%.2f;;;;",  $tcpActiveOpensRate);
    printf(" tcpPassiveOpensRate=%.2f;;;;", $tcpPassiveOpensRate);
    printf(" tcpAttemptFailsRate=%.2f;;;;", $tcpAttemptFailsRate);
    printf(" tcpEstabResetsRate=%.2f;;;;",  $tcpEstabResetsRate);

}

print "\n";

# Performance? 

if ($out =~ /Critical/) { exit $ERRORS {'CRITICAL'} }
if ($out =~ /Warning/)  { exit $ERRORS {'WARNING'}  }

exit (0); #OK

# Usage sub
sub print_usage () {
        print "Usage: $PROGNAME 
	[-C], --Community <community>
	[-h], --help
	[-H], --host
	[-i], --idle <warn:crit> percent (NOTE: idle less than x)
	[-n], --nice <warn:crit> percent
	[-o], --port <SNMP port>
	[-p] (output Nagios performance data)
	[-s], --system <warn:crit> percent
	[-t], --timeout
	[-u], --user <warn:crit> percent
	[-D] (debug) [-h] (help) [-V] (Version)\n";
}

# Help sub
sub print_help () {
        print_revision($PROGNAME,'$Revision$');

# Perl device CPU check plugin for Nagios

	print_usage();
	print "
-C, --Community
   SNMP Community string
-D, --debug
   Debug output
-h, --help
   Print help
-H, --host
   Hostname of the target system
-i, --idle
   If less than Percent CPU idle
-n, --nice
   Percent CPU nice
-o, --port
   SNMP port to use
-p, --performance
   Report Nagios performance data after the ouput string
-s, --system=STRING
   Percent CPU system
-t, --timeout
   Plugin timeout
-u, --user
   Percent CPU user
-v, --version
   SNMP version
-V, --progVersion
   Print version of plugin
";

}

sub check_for_errors {
	if ( $snmp_session->{ErrorNum} ) {
		print "UNKNOWN - error retrieving SNMP data: $snmp_session->{ErrorStr}\n";
		exit $ERRORS{UNKNOWN};
	}
}
