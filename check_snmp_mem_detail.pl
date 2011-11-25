#!/usr/local/groundwork/perl/bin/perl -w
#
# $Id$
#
# check_snmp_mem_detail.pl checks detail MEM values through SNMP.
# Copied from check_snmp_cpu_detail.pl
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
# 2-Nov-2010 - stevenpan@gmail.com
#	Initial revision
#
use strict;
use RRDs;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $memutilwarn = -1;
my $memutilcrit = -1;
my $actutilwarn = -1;
my $actutilcrit = -1;
my $swaputilwarn = -1;
my $swaputilcrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_V $opt_c $opt_D $opt_p $opt_h $opt_M $opt_A $opt_S);
use vars qw($opt_H $opt_m $opt_v $opt_o);
$opt_c = -1;
$opt_m = "public";
$opt_o = 161;
$opt_v = "2c";
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_mem_detail.pl";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"V"   => \$opt_V, "progVersion"	=> \$opt_V,
	"H=s" => \$opt_H, "host=s"		=> \$opt_H,
	"C=s" => \$opt_m, "Community=s"	=> \$opt_m,
	"t"   => \$TIMEOUT, "timeout"	=> \$TIMEOUT,
	"v"   => \$opt_v, "version"		=> \$opt_v,
	"M=s" => \$opt_M, "memutil=s" => \$opt_M,
	"A=s" => \$opt_A, "actutil=s" => \$opt_A,
	"S=s" => \$opt_S, "swaputil=s" => \$opt_S,
	"D"   => \$opt_D, "debug"		=> \$opt_D,
	"o"   => \$opt_o, "port"		=> \$opt_o,
	"p"   => \$opt_p, "performance"	=> \$opt_p,
	"h"   => \$opt_h, "help"		=> \$opt_h
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

# Need host name
if (!$opt_H) { die "-H <hostname> is required\n" }

# check snmp version
if ($opt_v && $opt_v !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_D) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_p) { $perf = 1; }

# Version
if ($opt_V) {
        print_revision($PROGNAME,'$Revision$');
        exit $ERRORS{'OK'};
}

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Options checking
if ($opt_M) { 
	($memutilwarn, $memutilcrit) = split /:/, $opt_M;

	($memutilwarn && $memutilcrit) || usage ("missing value -s <warn:crit>\n");

	($memutilwarn =~ /^\d{1,3}$/ && $memutilwarn > 0 && $memutilwarn <= 100) &&
	($memutilcrit =~ /^\d{1,3}$/ && $memutilcrit > 0 && $memutilcrit <= 100) ||
		usage("Invalid value: -M <warn:crit> (mem util percent): $opt_M\n");

	($memutilcrit > $memutilwarn) || 
		usage("mem util critical (-M $opt_M <warn:crit>) must be > warning\n");
}

if ($opt_A) { 
	($actutilwarn, $actutilcrit) = split /:/, $opt_A;

	($actutilwarn && $actutilcrit) || usage ("missing value -A <warn:crit>\n");

	($actutilwarn =~ /^\d{1,3}$/ && $actutilwarn > 0 && $actutilwarn <= 100) &&
	($actutilcrit =~ /^\d{1,3}$/ && $actutilcrit > 0 && $actutilcrit <= 100) ||
		usage("Invalid value: -A <warn:crit> (actual mem util percent): $opt_A\n");

	($actutilcrit > $actutilwarn) || 
		usage("actual mem util critical (-A $opt_A <warn:crit>) must be > warning\n");
}

if ($opt_S) { 
	($swaputilwarn, $swaputilcrit) = split /:/, $opt_S;

	($swaputilwarn && $swaputilcrit) || usage ("missing value -S <warn:crit>\n");

	($swaputilwarn =~ /^\d{1,3}$/ && $swaputilwarn > 0 && $swaputilwarn <= 100) &&
	($swaputilcrit =~ /^\d{1,3}$/ && $swaputilcrit > 0 && $swaputilcrit <= 100) ||
		usage("Invalid value: -S <warn:crit> (swap util percent): $opt_S\n");

	($swaputilcrit > $swaputilwarn) || 
		usage("swap util critical (-S $opt_S <warn:crit>) must be > warning\n");
}

my ($totalswap, $availswap, $totalmem, $availmem, $shared, $buffer, $cached) = undef;

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_m,
    RemotePort	=> $opt_o,
    Version	=> $opt_v
);

# retrieve the data from the remote host
($totalswap, $availswap, $totalmem, $availmem, $buffer, $cached) = $snmp_session->bulkwalk( 0, 6, 
	[['memTotalSwap'],
	 ['memAvailSwap'],
	 ['memTotalReal'],
	 ['memAvailReal'],
	 ['memBuffer'],
	 ['memCached']]
);
check_for_errors();

# Grab the values from the arrays
$totalswap = scalar(@$totalswap[0]->val);
$availswap = scalar(@$availswap[0]->val);
$totalmem = scalar(@$totalmem[0]->val);
$availmem = scalar(@$availmem[0]->val);
$shared = 0;
$buffer = scalar(@$buffer[0]->val);
$cached = scalar(@$cached[0]->val);

alarm (0); # Done with network

print "totalswap:$totalswap, availswap:$availswap, totalmem:$totalmem, availmem:$availmem, shared:$shared, buffer:$buffer, cached:$cached\n" if $debug;

my ($memused, $memfree, $actused, $actfree, $memutil, $actutil, $swaputil) = undef;
$memused = $totalmem - $availmem;
$memfree = $availmem;
$actused = $totalmem - $availmem - $shared - $buffer - $cached;
$actfree = $availmem + $shared + $buffer + $cached;
$memutil = $memused / $totalmem * 100;
$actutil = $actused / $totalmem * 100;
$swaputil = ( $totalswap - $availswap ) / $totalswap * 100;

print "memused:$memused, memfree:$memfree, actused:$actused, actfree:$actfree, memutil:$memutil, actutil:$actutil, swaputil:$swaputil\n" if $debug;

# Threshold checks
my $out = undef;

$out = $out . sprintf("TotalSwap: %.2fKB ", $totalswap);
$out = $out . sprintf("AvailSwap: %.2fKB ", $availswap);
$out = $out . sprintf("TotalMem: %.2fKB ", $totalmem);
$out = $out . sprintf("AvailMem: %.2fKB ", $availmem);
$out = $out . sprintf("Shared: %.2fKB ", $shared);
$out = $out . sprintf("Buffer: %.2fKB ", $buffer);
$out = $out . sprintf("Cached: %.2fKB ", $cached);

$out = $out . sprintf("memutil: %.2f%% ", $memutil);
if ($memutilcrit > 0) {
	($memutil > $memutilcrit) ? ($out = $out . "(Critical) ") :
		($memutil > $memutilwarn) ? ($out=$out . "(Warning) ") : 
			($out=$out."(OK) ");
} else {
	$out=$out."(OK) ";
}
$out = $out . sprintf("actutil: %.2f%% ", $actutil);
if ($actutilcrit > 0) {
	($actutil > $actutilcrit) ? ($out = $out . "(Critical) ") :
		($actutil > $actutilwarn) ? ($out=$out . "(Warning) ") : 
			($out=$out."(OK) ");
} else {
	$out=$out."(OK) ";
}
$out = $out . sprintf("swaputil: %.2f%% ", $swaputil);
if ($swaputilcrit > 0) {
	($swaputil > $swaputilcrit) ? ($out = $out . "(Critical) ") :
		($swaputil > $swaputilwarn) ? ($out=$out . "(Warning) ") : 
			($out=$out."(OK) ");
} else {
	$out=$out."(OK) ";
}

# Main output
print "$out";

# Performance output
if ($perf) {
	print " |";

	printf(" totalswap=%.2f;;;;", $totalswap);
	printf(" availswap=%.2f;;;;", $availswap);
	printf(" totalmem=%.2f;;;;", $totalmem);
	printf(" availmem=%.2f;;;;", $availmem);
	printf(" shared=%.2f;;;;", $shared);
	printf(" buffer=%.2f;;;;", $buffer);
	printf(" cached=%.2f;;;;", $cached);

	if ($memutilcrit < 0) { printf(" memutil=%.2f;;;;", $memutil) }
	else { printf(" memutil=%.2f;%d;%d;;", $memutil,$memutilwarn,$memutilcrit) }

	if ($actutilcrit < 0) { printf(" actutil=%.2f;;;;", $actutil) }
	else { printf(" actutil=%.2f;%d;%d;;", $actutil,$actutilwarn,$actutilcrit) }

	if ($swaputilcrit < 0) { printf(" swaputil=%.2f;;;;", $swaputil) }
	else { printf(" swaputil=%.2f;%d;%d;;", $swaputil,$swaputilwarn,$swaputilcrit) }

# sample
# totalswap=8385920.00;;;; availswap=8385920.00;;;; totalmem=8055524.00;;;; availmem=587000.00;;;; shared=0.00;;;; buffer=226260.00;;;; cached=5658420.00;;;; memutil=92.71%;;;; actutil=19.66%;;;; swaputil=0.00%;;;;

#`printf "totalswap=$totalswap;;;;\navailswap=$availswap;;;;\ntotalmem=$totalmem;;;;\navailmem=$availmem;;;;\nshared=$shared;;;;\nbuffer=$buffer;;;;\ncached=$cached;;;;\nmemutil=$memutil;;;;\nactutil=$actutil;;;;\nswaputil=$swaputil;;;;\n" |/usr/local/groundwork/nagios/libexec/perfdata_app.pl -H $opt_H -S check_snmp_mem_detail `;

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
	[-o], --port <SNMP port>
	[-M], --memutil <warn:crit> percent
	[-A], --actutil <warn:crit> percent
	[-S], --swaputil <warn:crit> percent
	[-p] (output Nagios performance data)
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
-w, --wait
   Percent CPU IO wait
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
