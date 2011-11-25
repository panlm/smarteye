#!/usr/local/groundwork/perl/bin/perl -w
#
# $Id$
#
# check_snmp_cpu_w.pl checks CPU values through SNMP.
# Copied from check_cpu_default.pl
#
# Copyright 2007 GroundWork Open Source, Inc. (“GroundWork”)  
# All rights reserved. This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License version 2 as published 
# by the Free Software Foundation.
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
# 4-Nov-2005 - Harper Mann
#	Initial revision
#
use strict;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $cpuwarn = -1;
my $cpucrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_c );
use vars qw($opt_H $opt_C $opt_V $opt_O $opt_D $opt_p $opt_h );
$opt_C = "public";
$opt_O = 161;
$opt_V = "2c";
# Watch out for this: snmpd updates every 5 secs by default
my $sleeptime = 6; # seconds
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "check_cpu";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"D"   => \$opt_D, "debug"		=> \$opt_D,
	"H=s" => \$opt_H, "hostname=s"		=> \$opt_H,
	"C=s" => \$opt_C, "community=s"	=> \$opt_C,
	"O"   => \$opt_O, "snmpport" => \$opt_O,
	"V"   => \$opt_V, "snmpversion"	=> \$opt_V,
	"t"   => \$TIMEOUT, "timeout"	=> \$TIMEOUT,
	"S"   => \$sleeptime, "sleeptime"	=> \$sleeptime,
	"c=s" => \$opt_c, "cpu=s"		=> \$opt_c,
	"p"   => \$opt_p, "performance"	=> \$opt_p,
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
# Percent CPU system utilization
if ($opt_c) { 
	($cpuwarn, $cpucrit) = split /:/, $opt_c;

	($cpuwarn && $cpucrit) || usage ("missing value -c <warn:crit>\n");

	($cpuwarn =~ /^\d{1,3}$/ && $cpuwarn > 0 && $cpuwarn <= 100) &&
	($cpucrit =~ /^\d{1,3}$/ && $cpucrit > 0 && $cpucrit <= 100) ||
		usage("Invalid value: -c <warn:crit> (cpu util percent): $opt_c\n");

	($cpucrit > $cpuwarn) || 
		usage("cpu util critical (-c $opt_c <warn:crit>) must be > warning\n");
}

# Read /proc/stat values.  The first "cpu " line has aggregate values if
# the system is SMP, otherwise, just get the requested CPU

my $cpu = undef;

# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_O,
    Version	=> $opt_V
);

# retrieve the data from the remote host
($cpu) = $snmp_session->bulkwalk( 0, 1, 
	[['hrProcessorLoad']]
);
check_for_errors();

alarm (0); # Done with network

# Grab the values from the arrays
#my $user = 0;
#$user = scalar(@$cpu[0]->val);
#printf "$user\n";
#printf "$#$cpu\n";

my $avg = 0;
for ( my $i = 0; $i <= $#$cpu; $i++ ) {
  $avg = $avg + scalar(@$cpu[$i]->val);
  printf "%d\n",scalar(@$cpu[$i]->val) if $debug;
}
$avg = $avg / ( $#$cpu + 1 );
printf "Average: $avg\n" if $debug;
$cpu = $avg;

# Threshold checks
my $out = undef;

$out = $out . sprintf("cpu: %.2f%% ", $cpu);
if ($cpucrit > 0) {
	($cpu > $cpucrit) ? ($out = $out . "(Critical) ") :
		($cpu > $cpuwarn) ? ($out=$out . "(Warning) ") : 
			($out=$out."(OK) ");
} else {
	$out=$out."(OK) ";
}

# Main output
print "$out";

# Performance output
if ($perf) {;
	print " |";

	if ($cpucrit < 0) { printf(" cpu=%.2f;;;;", $cpu) }
	else { printf(" cpu=%.2f;%d;%d;;", $cpu,$cpuwarn,$cpucrit) }

}

print "\n";

# Plugin output
# $worst == $ERRORS{'OK'} ?  print "CPU OK @goodlist" : print "@badlist";

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
