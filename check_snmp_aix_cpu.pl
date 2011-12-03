#!/usr/local/smarteye/perl/bin/perl -w
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
# 26-Dec-2011 - qq805772847@hotmail.com
#	Initial revision
#
#use strict;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $warn = -1;
my $crit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_C $opt_O $opt_V $opt_D $opt_p $opt_h $opt_H $opt_c);
$opt_C = "public";
$opt_O = 161;
$opt_V = "2c";

use vars qw($PROGNAME);
use lib "/usr/local/smarteye/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_aix_cpu";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"C=s" => \$opt_C, "community=s"		=> \$opt_C,
	"O"   => \$opt_O, "snmpport" 		=> \$opt_O,
	"V"   => \$opt_V, "snmpversion"		=> \$opt_V,
	"D"   => \$opt_D, "debug"		=> \$opt_D,
	"p"   => \$opt_p, "performance"		=> \$opt_p,
	"t=s"   => \$TIMEOUT, "timeout=s"	=> \$TIMEOUT,
	"H=s" => \$opt_H, "hostname=s"		=> \$opt_H,
	"c=s" => \$opt_c, "cpu=s"		=> \$opt_c,
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
	($warn, $crit) = split /:/, $opt_c;

	($warn && $crit) || usage ("missing value -c <warn:crit>\n");

	($crit > $warn) || 
		usage("CPU Util (-c $opt_c <warn:crit>) must be > warning\n");
}

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_O,
    Version	=> $opt_V
);

my $aixcpu = undef;
# retrieve the data from the remote host

$aixcpu = $snmp_session->get('enterprises.2.6.191.1.2.1.0');

check_for_errors();
alarm (0); # Done with network

print "CPU Util: $aixcpu \n" if $debug;

# Threshold checks
my $out = undef;

if ($crit > 0) {
	($aixcpu > $crit) ? ($out = "Critical") :
		($aixcpu > $warn) ? ($out= "Warning") : 
			($out= "OK");
} else {
	$out="OK";
}

$out = sprintf("%s - CPU Util is %s at %d ", $out, $out, $aixcpu);

# Main output
print "$out";

# Performance output
if ($perf) {;
	print " |";
	if ($crit < 0) {
	    printf("cpu_util=%d;;;;", $aixcpu) }
	else {
	    printf("cpu_util=%d;%d;%d;;", $aixcpu,$warn,$crit)
	}

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
	[-V], --snmpversion
	[-o], --port <SNMP port>
	[-H], --host
	[-c], --cpu <warn:crit> utilization 
	[-p] (output Nagios performance data)
	[-t], --timeout
	[-h], --help
	[-D] (debug) [-h] (help) [-V] (Version)\n";
}

# Help sub
sub print_help () {
        print_revision($PROGNAME,'$Revision$');

	print_usage();
	print "
-C, --Community
   SNMP Community string
-V, --snmpversion
   SNMP Version (1,2c,3)
-o, --port
   SNMP port to use
-H, --host
   Hostname of the target system
-c, --cpu
   Cpu <warn:crit> utilization
-p, --performance
   Report Nagios performance data after the ouput string
-t, --timeout
   Plugin timeout
-h, --help
   Print help
-D, --debug
   Debug output
";

}

sub check_for_errors {
	if ( $snmp_session->{ErrorNum} ) {
		print "UNKNOWN - error retrieving SNMP data: $snmp_session->{ErrorStr}\n";
		exit $ERRORS{UNKNOWN};
	}
}
