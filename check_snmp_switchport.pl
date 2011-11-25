#!/usr/local/groundwork/perl/bin/perl -w
#
# $Id$
#
# check_snmp_cpu_detail.pl checks detail CPU values through SNMP.
# Copied from check_snmp_cpu.pl
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
# 1-Nov-2010 - stevenpan@gmail.com
#	Initial revision
#
use strict;

my @sar_vals = undef;
my @lines = undef;
my @res = undef;

my $InDiscardRateWarn = -1;
my $InDiscardRateCrit = -1;
my $OutDiscardRateWarn = -1;
my $OutDiscardRateCrit = -1;
my $InErrorRateWarn = -1;
my $InErrorRateCrit = -1;
my $OutErrorRateWarn = -1;
my $OutErrorRateCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use vars qw($opt_V $opt_n $opt_h $opt_i $opt_o $opt_d $opt_D $opt_e $opt_E);
use vars qw($opt_H $opt_C $opt_P $opt_v $opt_f);
$opt_C = "yinjicomm";
$opt_P = 161;
$opt_v = "2c";
$opt_n = "0";
# Watch out for this: snmpd updates every 5 secs by default
my $sleeptime = 40; # seconds
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);

# default $TIMEOUT is 15 sec
$TIMEOUT=60;

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_net_detail.pl";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"h"   => \$opt_h, "help"		=> \$opt_h,
	"v"   => \$opt_v, "version"		=> \$opt_v,
	"V"   => \$opt_V, "debug"		=> \$opt_V,
	"H=s" => \$opt_H, "host=s"		=> \$opt_H,
	"C=s" => \$opt_C, "Community=s"	=> \$opt_C,
	"P"   => \$opt_P, "port"		=> \$opt_P,
	"t=s"   => \$TIMEOUT, "timeout=s"	=> \$TIMEOUT,
	"S=s"   => \$sleeptime, "sleeptime=s"	=> \$sleeptime,
	"d=s" => \$opt_d, "InDiscardRate=s" => \$opt_d,
	"D=s" => \$opt_D, "OutDiscardRate=s" => \$opt_D,
	"e=s" => \$opt_e, "InErrorRate=s" => \$opt_e,
	"E=s" => \$opt_E, "OutErrorRate=s" => \$opt_E,
	"n=s"   => \$opt_n, "SwitchPort=s" => \$opt_n,
	"f"   => \$opt_f, "performance" => \$opt_f
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Need Hostname
if (!$opt_H) { die "-H <hostname> is required\n" }

# check snmp version
if ($opt_v && $opt_v !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_V) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_f) { $perf = 1; }

# Options checking
if ($opt_d) { 
	($InDiscardRateWarn, $InDiscardRateCrit) = split /:/, $opt_d;

	($InDiscardRateWarn && $InDiscardRateCrit) || usage ("missing value -d <warn:crit>\n");

	($InDiscardRateWarn =~ /^\d{1,3}$/ && $InDiscardRateWarn > 0 && $InDiscardRateWarn <= 100) &&
	($InDiscardRateCrit =~ /^\d{1,3}$/ && $InDiscardRateCrit > 0 && $InDiscardRateCrit <= 100) ||
		usage("Invalid value: -d <warn:crit> (In Discard Rate Percent): $opt_d\n");

	($InDiscardRateCrit > $InDiscardRateWarn) || 
		usage("critical (-d $opt_d <warn:crit>) must be > warning\n");
}
print "InDiscardRateWarn:$InDiscardRateWarn; InDiscardRateCrit:$InDiscardRateCrit\n" if $debug;
if ($opt_D) { 
	($OutDiscardRateWarn, $OutDiscardRateCrit) = split /:/, $opt_D;

	($OutDiscardRateWarn && $OutDiscardRateCrit) || usage ("missing value -D <warn:crit>\n");

	($OutDiscardRateWarn =~ /^\d{1,3}$/ && $OutDiscardRateWarn > 0 && $OutDiscardRateWarn <= 100) &&
	($OutDiscardRateCrit =~ /^\d{1,3}$/ && $OutDiscardRateCrit > 0 && $OutDiscardRateCrit <= 100) ||
		usage("Outvalid value: -D <warn:crit> (Out Discard Rate Percent): $opt_D\n");

	($OutDiscardRateCrit > $OutDiscardRateWarn) || 
		usage("critical (-D $opt_D <warn:crit>) must be > warning\n");
}
print "OutDiscardRateWarn:$OutDiscardRateWarn; OutDiscardRateCrit:$OutDiscardRateCrit\n" if $debug;
if ($opt_e) { 
	($InErrorRateWarn, $InErrorRateCrit) = split /:/, $opt_e;

	($InErrorRateWarn && $InErrorRateCrit) || usage ("missing value -e <warn:crit>\n");

	($InErrorRateWarn =~ /^\d{1,3}$/ && $InErrorRateWarn > 0 && $InErrorRateWarn <= 100) &&
	($InErrorRateCrit =~ /^\d{1,3}$/ && $InErrorRateCrit > 0 && $InErrorRateCrit <= 100) ||
		usage("Invalid value: -e <warn:crit> (In Error Rate Percent): $opt_e\n");

	($InErrorRateCrit > $InErrorRateWarn) || 
		usage("critical (-e $opt_e <warn:crit>) must be > warning\n");
}
print "InErrorRateWarn:$InErrorRateWarn; InErrorRateCrit:$InErrorRateCrit\n" if $debug;
if ($opt_E) { 
	($OutErrorRateWarn, $OutErrorRateCrit) = split /:/, $opt_E;

	($OutErrorRateWarn && $OutErrorRateCrit) || usage ("missing value -E <warn:crit>\n");

	($OutErrorRateWarn =~ /^\d{1,3}$/ && $OutErrorRateWarn > 0 && $OutErrorRateWarn <= 100) &&
	($OutErrorRateCrit =~ /^\d{1,3}$/ && $OutErrorRateCrit > 0 && $OutErrorRateCrit <= 100) ||
		usage("Outvalid value: -E <warn:crit> (Out Error Rate Percent): $opt_E\n");

	($OutErrorRateCrit > $OutErrorRateWarn) || 
		usage("critical (-E $opt_E <warn:crit>) must be > warning\n");
}
print "OutErrorRateWarn:$OutErrorRateWarn; OutErrorRateCrit:$OutErrorRateCrit\n" if $debug;

# Percent CPU system utilization
#if ($opt_s) { 
#	($syswarn, $syscrit) = split /:/, $opt_s;
#
#	($syswarn && $syscrit) || usage ("missing value -s <warn:crit>\n");
#
#	($syswarn =~ /^\d{1,3}$/ && $syswarn > 0 && $syswarn <= 100) &&
#	($syscrit =~ /^\d{1,3}$/ && $syscrit > 0 && $syscrit <= 100) ||
#		usage("Invalid value: -s <warn:crit> (system percent): $opt_s\n");
#
#	($syscrit > $syswarn) || 
#		usage("system critical (-s $opt_s <warn:crit>) must be > warning\n");
#}

# Percent CPU idle utilzation
#if ($opt_i) {
#	($idlewarn, $idlecrit) = split /:/, $opt_i;
#
#	($idlewarn && $idlecrit) || usage ("missing value -i <warn:crit>\n");
#
#	($idlewarn =~ /^\d{1,3}$/ && $idlewarn > 0 && $idlewarn <= 100) &&
#	($idlecrit =~ /^\d{1,3}$/ && $idlecrit > 0 && $idlecrit <= 100) ||
#		usage("Invalid value: -i <warn:crit> (idle percent): $opt_i\n");
#
#	($idlecrit < $idlewarn) || 
#		usage("idle critical (-i $opt_i <warn:crit>) must be > warning\n");
#}

# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_P,
    Version	=> $opt_v
);

printf "port number:$opt_n\n" if $debug;

my ($tmp_in, $tmp_inupkt, $tmp_innupkt, $tmp_out, $tmp_outupkt, $tmp_outnupkt, $tmp_indiscard, $tmp_outdiscard, $tmp_inerror, $tmp_outerror) = undef;
# retrieve the data from the remote host
($tmp_in, $tmp_inupkt, $tmp_innupkt, $tmp_out, $tmp_outupkt, $tmp_outnupkt, $tmp_indiscard, $tmp_outdiscard, $tmp_inerror, $tmp_outerror) = $snmp_session->get(
  [['ifInOctets',$opt_n],
   ['ifInUcastPkts',$opt_n],
   ['ifInNUcastPkts',$opt_n],
   ['ifOutOctets',$opt_n],
   ['ifOutUcastPkts',$opt_n],
   ['ifOutNUcastPkts',$opt_n],
   ['ifInDiscards',$opt_n],
   ['ifOutDiscards',$opt_n],
   ['ifInErrors',$opt_n],
   ['ifOutErrors',$opt_n]]
);

print "in\t\tinupkt\t\tinnupkt\t\tout\t\toutupkt\t\toutnupkt\tindiscard\toutdiscard\tinerror\tinerror\n" if $debug;
print "$tmp_in\t$tmp_inupkt\t$tmp_innupkt\t$tmp_out\t$tmp_outupkt\t$tmp_outnupkt\t$tmp_indiscard\t\t$tmp_outdiscard\t\t$tmp_inerror\t$tmp_outerror \n" if $debug;

# need to sleep to get delta
sleep $sleeptime;

my ($in, $inupkt, $innupkt, $out, $outupkt, $outnupkt, $indiscard, $outdiscard, $inerror, $outerror) = undef;
# retrieve the data from the remote host
($in, $inupkt, $innupkt, $out, $outupkt, $outnupkt, $indiscard, $outdiscard, $inerror, $outerror) = $snmp_session->get(
  [['ifInOctets',$opt_n],
   ['ifInUcastPkts',$opt_n],
   ['ifInNUcastPkts',$opt_n],
   ['ifOutOctets',$opt_n],
   ['ifOutUcastPkts',$opt_n],
   ['ifOutNUcastPkts',$opt_n],
   ['ifInDiscards',$opt_n],
   ['ifOutDiscards',$opt_n],
   ['ifInErrors',$opt_n],
   ['ifOutErrors',$opt_n]]
);

print "in\t\tinupkt\t\tinnupkt\t\tout\t\toutupkt\t\toutnupkt\tindiscard\toutdiscard\tinerror\tinerror\n" if $debug;
print "$in\t$inupkt\t$innupkt\t$out\t$outupkt\t$outnupkt\t$indiscard\t\t$outdiscard\t\t$inerror\t$outerror \n" if $debug;

alarm (0); # Done with network

if ($in < $tmp_in ) {
    $in = 4294967295 + $in +1;
}
if ($out < $tmp_out ) {
    $out = 4294967295 + $out +1;
}

#debug ifInOctets
#my $current = `/bin/date +"%Y%m%d %H%M%S"`;
#chomp $current;
#open( FILE, '>>', '/tmp/switchport-2.log' );
#print FILE "$current\t$opt_H\t$opt_n\t$tmp_in\t$in";
#print FILE "\n";
#close FILE;

# Calculate Here
my ($inbit, $outbit, $inrate, $outrate, $inpkt, $outpkt, $indiscardrate, $outdiscardrate, $inerrorrate, $outerrorrate) = undef;
$inbit = ( $in - $tmp_in ) * 8 / $sleeptime ;
$outbit = ( $out - $tmp_out ) * 8 / $sleeptime ;
#$inrate = $inbit / $speed * 100 ;
#$outrate = $outbit / $speed * 100 ;
$inpkt = ( $inupkt - $tmp_inupkt ) + ( $innupkt - $tmp_innupkt ) ;
$outpkt = ( $outupkt - $tmp_outupkt ) + ( $outnupkt - $tmp_outnupkt ) ;
if ( ! $inpkt ) { $inpkt = $inpkt + 1; }
if ( ! $outpkt ) { $outpkt = $outpkt + 1; }
$indiscardrate = ( $indiscard - $tmp_indiscard ) / $inpkt * 100 ;
$outdiscardrate = ( $outdiscard - $tmp_outdiscard ) / $outpkt * 100 ;
$inerrorrate = ( $inerror - $tmp_inerror ) / $inpkt * 100 ;
$outerrorrate = ( $outerror - $tmp_outerror ) / $outpkt * 100 ;

print "inbit:$inbit, outbit:$outbit, indiscardrate:$indiscardrate, outdiscardrate:$outdiscardrate, inerrorrate:$inerrorrate, outerrorrate:$outerrorrate\n" if $debug;

#debug ifInOctets
#print FILE "\t$inbit\t$tmp_out\t$out\t$outbit\n";
#close FILE;

# Threshold checks
my $output = undef;

$output = $output . sprintf("In: %.2fbps ", $inbit);
$output = $output . sprintf("Out: %.2fbps ", $outbit);
$output = $output . sprintf("InDiscardRate: %.2f%% ", $indiscardrate);
if ($InDiscardRateCrit > 0) {
	($indiscardrate > $InDiscardRateCrit) ? ($output = $output . "(Critical) ") :
		($indiscardrate > $InDiscardRateWarn) ? ($output = $output . "(Warning) ") : 
			($output = $output."(OK) ");
} else {
	$output=$output."(OK) ";
}
$output = $output . sprintf("OutDiscardRate: %.2f%% ", $outdiscardrate);
if ($OutDiscardRateCrit > 0) {
	($outdiscardrate > $OutDiscardRateCrit) ? ($output = $output . "(Critical) ") :
		($outdiscardrate > $OutDiscardRateWarn) ? ($output = $output . "(Warning) ") : 
			($output = $output . "(OK) ");
} else {
	$output=$output."(OK) ";
}
$output = $output . sprintf("InErrorRate: %.2f%% ", $inerrorrate);
if ($InErrorRateCrit > 0) {
	($inerrorrate > $InErrorRateCrit) ? ($output = $output . "(Critical) ") :
		($inerrorrate > $InErrorRateWarn) ? ($output = $output . "(Warning) ") : 
			($output = $output."(OK) ");
} else {
	$output=$output."(OK) ";
}
$output = $output . sprintf("OutErrorRate: %.2f%% ", $outerrorrate);
if ($OutErrorRateCrit > 0) {
	($outerrorrate > $OutErrorRateCrit) ? ($output = $output . "(Critical) ") :
		($outerrorrate > $OutErrorRateWarn) ? ($output = $output . "(Warning) ") : 
			($output = $output . "(OK) ");
} else {
	$output=$output."(OK) ";
}

# Main output
print "$output";

# Performance output
if ($perf) {;
	print " |";
	printf(" In=%.2f;;;;",$inbit);
	printf(" Out=%.2f;;;;",$outbit);
	if ($InDiscardRateCrit < 0) { printf(" InDiscardRate=%.2f;;;;", $indiscardrate) }
	else { printf(" InDiscardRate=%.2f;%d;%d;;", $indiscardrate,$InDiscardRateWarn,$InDiscardRateCrit) }
	if ($OutDiscardRateCrit < 0) { printf(" OutDiscardRate=%.2f;;;;", $outdiscardrate) }
	else { printf(" OutDiscardRate=%.2f;%d;%d;;", $outdiscardrate,$OutDiscardRateWarn,$OutDiscardRateCrit) }
	if ($InErrorRateCrit < 0) { printf(" InErrorRate=%.2f;;;;", $inerrorrate) }
	else { printf(" InErrorRate=%.2f;%d;%d;;", $inerrorrate,$InErrorRateWarn,$InErrorRateCrit) }
	if ($OutErrorRateCrit < 0) { printf(" OutErrorRate=%.2f;;;;", $outerrorrate) }
	else { printf(" OutErrorRate=%.2f;%d;%d;;", $outerrorrate,$OutErrorRateWarn,$OutErrorRateCrit) }
}

print "\n";

# Plugin output
# $worst == $ERRORS{'OK'} ?  print "CPU OK @goodlist" : print "@badlist";

# Performance? 

if ($output =~ /Critical/) { exit $ERRORS {'CRITICAL'} }
if ($output =~ /Warning/)  { exit $ERRORS {'WARNING'}  }

exit (0); #OK

# Usage sub
sub print_usage () {
        print "Usage: $PROGNAME 
	[-h], --help
	[-V], --debug
	[-H], --host
	[-C], --Community <community>
	[-P], --port snmp_port (default 161)
	[-v], --version snmp_version (default 2c)
	[-d], --InDiscardRate <warn:crit> percent
	[-D], --OutDiscardRate <warn:crit> percent
	[-e], --InErrorRate <warn:crit> percent
	[-E], --OutErrorRate <warn:crit> percent
	[-n], --SwitchPort <switchport> (default 2)
	[-f] (output Nagios performance data)
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

