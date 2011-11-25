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

my $connwarn = -1;
my $conncrit = -1;

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
	"c=s" => \$opt_c, "conn=s"		=> \$opt_c,
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

my ($tcpMaxConn, $tcpActiveOpens, $tcpPassiveOpens, $tcpAttemptFails, $tcpEstabResets, $tcpCurrEstab) = undef;
# retrieve the data from the remote host
($tcpMaxConn, $tcpActiveOpens, $tcpPassiveOpens, $tcpAttemptFails, $tcpEstabResets, $tcpCurrEstab) = $snmp_session->get(
  [['tcpMaxConn',0],
   ['tcpActiveOpens',0],
   ['tcpPassiveOpens',0],
   ['tcpAttemptFails',0],
   ['tcpEstabResets',0],
   ['tcpCurrEstab',0]]
);
check_for_errors();

alarm (0); # Done with network

printf "conn: $tcpCurrEstab\n" if $debug;
printf "tcpMaxConn:$tcpMaxConn, tcpActiveOpens:$tcpActiveOpens, tcpPassiveOpens:$tcpPassiveOpens, tcpAttemptFails:$tcpAttemptFails, tcpEstabResets:$tcpEstabResets, tcpCurrEstab:$tcpCurrEstab\n" if $debug;

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

# Main output
print "$out";

# Performance output
if ($perf) {;
	print " |";

	if ($conncrit < 0) { printf(" conn=%d;;;;", $tcpCurrEstab) }
	else { printf(" conn=%d;%d;%d;;", $tcpCurrEstab,$connwarn,$conncrit) }

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
