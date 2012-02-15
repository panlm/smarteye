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

my $dskwarn = -1;
my $dskcrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_d $opt_l);
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

$PROGNAME = "check_mem";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"D"   => \$opt_D, "debug"		=> \$opt_D,
	"H=s" => \$opt_H, "hostname=s"		=> \$opt_H,
	"C=s" => \$opt_C, "community=s"	=> \$opt_C,
	"O"   => \$opt_O, "snmpport" => \$opt_O,
	"V"   => \$opt_V, "snmpversion"	=> \$opt_V,
	"t"   => \$TIMEOUT, "timeout"	=> \$TIMEOUT,
	"S"   => \$sleeptime, "sleeptime"	=> \$sleeptime,
	"d=s" => \$opt_d, "dsk=s"		=> \$opt_d,
	"l=s" => \$opt_l, "dsklabel=s"		=> \$opt_l,
	"p"   => \$opt_p, "performance"	=> \$opt_p,
	"h"   => \$opt_h, "help"		=> \$opt_h
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

# Need host name
if (!$opt_H) { die "-H <hostname> is required\n" }
if (!$opt_l) { die "-l <dsklabel> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_D) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_p) { $perf = 1; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Options checking
# Percent CPU system utilization
if ($opt_d) { 
	($dskwarn, $dskcrit) = split /:/, $opt_d;

	($dskwarn && $dskcrit) || usage ("missing value -d <warn:crit>\n");

	($dskwarn =~ /^\d{1,3}$/ && $dskwarn > 0 && $dskwarn <= 100) &&
	($dskcrit =~ /^\d{1,3}$/ && $dskcrit > 0 && $dskcrit <= 100) ||
		usage("Invalid value: -d <warn:crit> (dsk util percent): $opt_d\n");

	($dskcrit > $dskwarn) || 
		usage("dsk util critical (-d $opt_d <warn:crit>) must be > warning\n");
}


# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_O,
    Version	=> $opt_V
);

# retrieve the data from the remote host
my ($dskidx, $dsktype, $dskdesc) = undef;
($dskidx, $dsktype, $dskdesc) = $snmp_session->bulkwalk( 0, 3, 
	[['hrStorageIndex'],
	['hrStorageType'],
	['hrStorageDescr']]
);
check_for_errors();

my ($string, $string2, $i, $found) = undef;
for ( $i = 0; $i <= $#$dsktype; $i++ ) {
  $string = scalar(@$dsktype[$i]->val);
  $string2 = scalar(@$dskdesc[$i]->val);
  printf "%s\n",scalar(@$dsktype[$i]->val) if $debug;
  if ( $string =~ /\.1\.3\.6\.1\.2\.1\.25\.2\.1\.4/ && $string2 =~ /^$opt_l/ ) {
    # HOST-RESOURCES-TYPES::hrStorageFixedDisk = .1.3.6.1.2.1.25.2.1.4
    $found = 1;
    last;
  }
}
printf "i:$i\n" if $debug;
if ( !$found ) {
  printf "label not found\n";
  exit 2;
}
$found = scalar(@$dskidx[$i]->val);
printf "found:$found\n" if $debug;

my ($dskunit, $dsksize, $dskused) = undef;
($dskunit, $dsksize, $dskused) = $snmp_session->get(
	[['hrStorageAllocationUnits',$found],
	['hrStorageSize',$found],
	['hrStorageUsed',$found]]
);
check_for_errors();

alarm (0); # Done with network

# Grab the values from the arrays
#my $user = undef;
#$user = scalar(@$cpu[0]->val);
#printf "$user\n";
#printf "$#$cpu\n";

my $dskutil = undef;
$dsksize = $dsksize * $dskunit / 1024 / 1024;
$dskused = $dskused * $dskunit / 1024 / 1024;
$dskutil = $dskused / $dsksize * 100;
printf "dsksize=$dsksize MB, dskused=$dskused MB, dskutil=$dskutil %%\n" if $debug;

# Threshold checks
my $out = undef;

$out = $out . sprintf("dskutil: %.2f%% ", $dskutil);
if ($dskcrit > 0) {
	($dskutil > $dskcrit) ? ($out = $out . "(Critical) ") :
		($dskutil > $dskwarn) ? ($out=$out . "(Warning) ") : 
			($out=$out."(OK) ");
} else {
	$out=$out."(OK) ";
}

# Main output
print "$out";

# Performance output
if ($perf) {;
	print " |";

	printf (" dsksize=%.2f;;;%.2f;%.2f", $dsksize, 0, $dsksize);
	printf (" dskused=%.2f;;;%.2f;%.2f", $dskused, 0, $dsksize);
	if ($dskcrit < 0) { printf(" dskutil=%.2f;;;;", $dskutil) }
	else { printf(" dskutil=%.2f;%d;%d;0;100", $dskutil,$dskwarn,$dskcrit) }

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
