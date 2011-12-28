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
# 28-Dec-2011 - stevenpan@gmail.com
#	Initial revision
#
use strict;

my $DiskWarn = -1;
my $DiskCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use Data::Dumper;
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_l $opt_t $opt_d);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
my $sleeptime = 6; # seconds

sub print_help ();
sub print_usage ();

$PROGNAME = "check_snmp_storage";

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
	"l=s" => \$opt_l, "disklabel=s"      => \$opt_l,
	"t=s" => \$opt_t, "disktype=s"       => \$opt_t,
	"d=s" => \$opt_d, "disk=s"           => \$opt_d,
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

# Need host name
if (!$opt_H) { die "-H <hostname> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_v) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_f) { $perf = 1; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Options checking
if ($opt_d) { 
	($DiskWarn, $DiskCrit) = split /:/, $opt_d;

	($DiskWarn && $DiskCrit) || usage ("missing value -d <warn:crit>\n");

	($DiskWarn =~ /^\d{1,3}$/ && $DiskWarn > 0 && $DiskWarn <= 100) &&
	($DiskCrit =~ /^\d{1,3}$/ && $DiskCrit > 0 && $DiskCrit <= 100) ||
		usage("Invalid value: -d <warn:crit> (storage util percent): $opt_d\n");

	($DiskCrit > $DiskWarn) || 
		usage("storage util critical (-d $opt_d <warn:crit>) must be > warning\n");
}
print "DiskWarn:$DiskWarn; DiskCrit:$DiskCrit\n" if $debug;
if ( ! $opt_l && ! $opt_t ) { die "-l <disklabel> or -t <disktype> is required\n" }

# Get the kernel/system statistic values from SNMP

alarm ( $TIMEOUT ); # Don't hang Nagios

my $snmp_session = new SNMP::Session (
    DestHost	=> $opt_H,
    Community 	=> $opt_C,
    RemotePort	=> $opt_P,
    Version	=> $opt_V
);

my ($storageidx, $storagetype, $storagedesc) = undef;
my ($arr, $arr1, $arr2, $arr3) = undef;
if ( $opt_V eq "2c" ) {
    ($arr1, $arr2, $arr3) = $snmp_session->bulkwalk( 0, 3, [
        ['hrStorageIndex'],
        ['hrStorageType'],
        ['hrStorageDescr']
    ]);
    check_for_errors();
    for ( my $i = 0; $i <= $#$arr1; $i++ ) {
        @$storageidx[$i]  = scalar(@$arr1[$i]->val);
        @$storagetype[$i] = scalar(@$arr2[$i]->val);
        @$storagedesc[$i] = scalar(@$arr3[$i]->val);
    }
} else {
    # gettable hrStorageTable .1.3.6.1.2.1.25.2.3
    ($arr) = $snmp_session->gettable('.1.3.6.1.2.1.25.2.3');
    check_for_errors();
    my ($c, $key, $value) = undef;
    my $i = 0;
    for $c (sort keys %$arr ) {
        #print "$c: \n" if $debug;
        while(($key,$value) = each %{@$arr{$c}}) {
            print "$key => $value \n" if $debug;
            if ( $key eq "hrStorageDescr" ) {
                @$storagedesc[$i] = $value ;
            } elsif ( $key eq "hrStorageIndex" ) {
                @$storageidx[$i] = $value ;
            } elsif ( $key eq "hrStorageType" ) {
                @$storagetype[$i] = $value ;
                $i++;
            } else {
                next;
            }
        }
    }
}

#print Dumper($arr);
#print Dumper($storagedesc);
#print Dumper($storageidx);
#print Dumper($storagetype);

my ($i, $found) = undef;
for ( $i = 0; $i <= $#$storagetype; $i++ ) {
    # .1.3.6.1.2.1.25.2.1.2 hrStorageRam
    # .1.3.6.1.2.1.25.2.1.4 hrStorageFixedDisk
    if ( defined $opt_l ) {
        if ( @$storagedesc[$i] eq "$opt_l" ) {
            $found = 1;
            last;
        }
    }
    if ( defined $opt_t ) {
        if ( @$storagetype[$i] eq "$opt_t" || @$storagetype[$i] eq ".1.3.6.1.2.1.25.2.1.2" ) {
            $found = 1;
            last;
        }
    }
}
printf "i:$i\n" if $debug;
if ( !$found ) {
  printf "label not found\n";
  exit;
}
$found = @$storageidx[$i];
printf "found:$found\n" if $debug;

my ($storageunit, $storagesize, $storageused) = undef;
($storageunit, $storagesize, $storageused) = $snmp_session->get(
	[['hrStorageAllocationUnits',$found],
	['hrStorageSize',$found],
	['hrStorageUsed',$found]]
);
check_for_errors();

alarm (0); # Done with network

my $storageutil = undef;
$storagesize = $storagesize * $storageunit / 1024 / 1024;
$storageused = $storageused * $storageunit / 1024 / 1024;
$storageutil = $storageused / $storagesize * 100;
printf "storagesize=$storagesize MB, storageused=$storageused MB, storageutil=$storageutil %%\n" if $debug;

# Threshold checks
my $out = undef;

$out = $out . sprintf("storageutil: %.2f%% ", $storageutil);
if ($DiskCrit > 0) {
    ($storageutil > $DiskCrit) ? ($out = $out . "(Critical) ") :
        ($storageutil > $DiskWarn) ? ($out=$out . "(Warning) ") : 
        ($out=$out."(OK) ");
} else {
    $out=$out."(OK) ";
}

# Main output
print "$out";

# Performance output
if ($perf) {;
    print " |";
    printf (" storagesize=%.2f;;;;", $storagesize);
    printf (" storageused=%.2f;;;;", $storageused);
    if ($DiskCrit < 0) { printf(" storageutil=%.2f;;;;", $storageutil) }
    else { printf(" storageutil=%.2f;%d;%d;;", $storageutil,$DiskWarn,$DiskCrit) }
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
    [-h], --help
    [-v], --debug
    [-f], --performance             (output Nagios performance data)
    [-T], --timeout <seconds>       (default is $TIMEOUT)
    [-S], --sleeptime <seconds>     (default is $sleeptime)
    [-C], --community <community>
    [-P], --port <snmp_port>        (default is $opt_P)
    [-V], --version <snmp_version>  (default is $opt_V)
    [-H], --host <ip>
    [-l], --disklabel <disklabel>
    [-t], --disktype <disktype>
    [-d], --disk <warn:crit>
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
