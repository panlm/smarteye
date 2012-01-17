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
#        Initial revision
#
use strict;

my $InWarn = -1;
my $InCrit = -1;
my $OutWarn = -1;
my $OutCrit = -1;
my $ConnWarn = -1;
my $ConnCrit = -1;

my $debug = 0;
my $perf = 0;

#sysUpTimeInstance
my $uptimeoid = ".1.3.6.1.2.1.1.3.0";

use SNMP;
use Getopt::Long;
use vars qw($opt_h $opt_v $opt_f $opt_C $opt_P $opt_V);
use vars qw($opt_H $opt_i $opt_o $opt_d $opt_c);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
my $opt_n = 0;
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s
my $sleeptime = 50; # seconds

sub print_help ();
sub print_usage ();

my $tmp_dir = "/var/tmp";
$PROGNAME = "check_snmp_throughput";

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
        "h"   => \$opt_h, "help"             => \$opt_h,
        "v"   => \$opt_v, "debug"            => \$opt_v,
        "f"   => \$opt_f, "performance"      => \$opt_f,
        "T=s" => \$TIMEOUT, "timeout=s"      => \$TIMEOUT,
        "S=s" => \$sleeptime, "sleeptime=s"  => \$sleeptime,
        "C=s" => \$opt_C, "community=s"      => \$opt_C,
        "P=s" => \$opt_P, "port=s"           => \$opt_P,
        "V=s" => \$opt_V, "version=s"        => \$opt_V,
        "H=s" => \$opt_H, "host=s"           => \$opt_H,
        "i=s" => \$opt_i, "in=s"             => \$opt_i,
        "o=s" => \$opt_o, "out=s"            => \$opt_o,
        "d=s" => \$opt_d, "device=s"         => \$opt_d,
        "c=s" => \$opt_c, "connections=s"    => \$opt_c,
);

if ($status == 0) { print_usage() ; exit $ERRORS{'UNKNOWN'}; }

if ($opt_h) {print_help(); exit $ERRORS{'UNKNOWN'}}

# Need Hostname
if (!$opt_H) { die "-H <hostname> is required\n" }

# Need Device Address
if (!$opt_d) { die "-d <device-addr> is required\n" }

# check snmp version
if ($opt_V && $opt_V !~ /1|2c/) { die "SNMP V1 or V2c only\n" }

# Debug switch
if ($opt_v) { $SNMP::debugging = 1; $debug = 1 }

# Performance switch
if ($opt_f) { $perf = 1; }

# Options checking
if ($opt_i) { 
        ($InWarn, $InCrit) = split /:/, $opt_i;

        ($InWarn && $InCrit) || usage ("missing value -i <warn:crit>\n");

        ($InWarn =~ /^\d+$/ && $InWarn > 0) &&
        ($InCrit =~ /^\d+$/ && $InCrit > 0) ||
                usage("Invalid value: -i <warn:crit> (In): $opt_i\n");

        ($InCrit > $InWarn) || 
                usage("critical (-i $opt_i <warn:crit>) must be > warning\n");
}
print "InWarn:$InWarn; InCrit:$InCrit\n" if $debug;
if ($opt_o) { 
        ($OutWarn, $OutCrit) = split /:/, $opt_o;

        ($OutWarn && $OutCrit) || usage ("missing value -o <warn:crit>\n");

        ($OutWarn =~ /^\d+$/ && $OutWarn > 0) &&
        ($OutCrit =~ /^\d+$/ && $OutCrit > 0) ||
                usage("Invalid value: -o <warn:crit> (Out): $opt_o\n");

        ($OutCrit > $OutWarn) || 
                usage("critical (-o $opt_o <warn:crit>) must be > warning\n");
}
print "OutWarn:$OutWarn; OutCrit:$OutCrit\n" if $debug;
if ($opt_c) { 
        ($ConnWarn, $ConnCrit) = split /:/, $opt_c;

        ($ConnWarn && $ConnCrit) || usage ("missing value -c <warn:crit>\n");

        ($ConnWarn =~ /^\d+$/ && $ConnWarn > 0) &&
        ($ConnCrit =~ /^\d+$/ && $ConnCrit > 0) ||
                usage("Invalid value: -c <warn:crit> (Connections): $opt_c\n");

        ($ConnCrit > $ConnWarn) || 
                usage("critical (-c $opt_c <warn:crit>) must be > warning\n");
}
print "ConnWarn:$ConnWarn; ConnCrit:$ConnCrit\n" if $debug;

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;

my $history_file_name = $PROGNAME . "_" . $opt_d . "_" . $opt_H;
print "$tmp_dir/$history_file_name\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_d,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my ($string) = undef;
($string) = $snmp_session->bulkwalk(0,1,[
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.1']
]);
check_for_errors();

my $str1 = "";
my $i = 0;
for ( $i = 0; $i <= $#$string; $i++ ) {
    if ( @$string[$i]->val =~ /^$opt_H$/ ) {
        printf "%s\n",@$string[$i]->val if $debug;
        $str1 = @$string[$i]->val;
        last;
    }
}
if ( $str1 =~ /^$/ ) { die "host ip (-H) cannot be found in device (-d)\n" }

my $oid = "13";
for ( $i = 0; $i < length($str1); $i++ ) {
    $oid = $oid . "." . ord(substr($str1,$i,1));
}
printf "$oid\n" if $debug;

my ($last_check_time, $tmp_in, $tmp_out) = undef;
if ( -r "$tmp_dir/$history_file_name" ) {
    open(FILE,"<$tmp_dir/$history_file_name");
    $last_check_time = <FILE>; chomp($last_check_time);
    $tmp_in = <FILE>;          chomp($tmp_in);
    $tmp_out = <FILE>;         chomp($tmp_out);
    close(FILE);
} else {
    ($last_check_time, $tmp_in, $tmp_out) = $snmp_session->get([
        [$uptimeoid],
        ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.4',$oid],
        ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.6',$oid]
    ]);
    check_for_errors();

    # need to sleep to get delta
    sleep $sleeptime;
}

printf "time: %s\t in:%s\t out:%s\n",$last_check_time,$tmp_in,$tmp_out if $debug;

my ($check_time, $in, $out, $conn) = undef;
($check_time, $in, $out, $conn) = $snmp_session->get([
    [$uptimeoid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.4',$oid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.6',$oid],
    ['1.3.6.1.4.1.22610.2.4.3.4.2.1.1.9',$oid]
]);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$in\n";
    print FILE "$out\n";
    #print FILE join(",", @arr_mvalues)."\n";
    #print FILE join(",", @arr_values)."\n";
    close(FILE);
}

printf "time: %s\t in:%s\t out:%s\t conn:%s\n",$check_time,$in,$out,$conn if $debug;

alarm (0); # Done with network

# deal reboot
if ( $last_check_time > $check_time ) {
    exit (0);
}

# deal wrap
if ( $in < $tmp_in   ) { $in = 4294967295 + $in +1;   }
if ( $out < $tmp_out ) { $out = 4294967295 + $out +1; }

# Calculate Here
my ($delta, $inbit, $outbit) = undef;
$delta = ( $check_time - $last_check_time ) / 100; print "delta: $delta\n" if $debug;
$inbit = ( $in - $tmp_in ) * 8 / $delta ;
$outbit = ( $out - $tmp_out ) * 8 / $delta ;

# Threshold checks
my $output = undef;

$output = $output . sprintf("In: %.2fbps ", $inbit);
if ($InCrit > 0) {
        ($inbit > $InCrit) ? ($output = $output . "(Critical) ") :
                ($inbit > $InWarn) ? ($output = $output . "(Warning) ") :
                        ($output = $output."(OK) ");
} else {
        $output=$output."(OK) ";
}
$output = $output . sprintf("Out: %.2fbps ", $outbit);
if ($OutCrit > 0) {
        ($outbit > $OutCrit) ? ($output = $output . "(Critical) ") :
                ($outbit > $OutWarn) ? ($output = $output . "(Warning) ") :
                        ($output = $output . "(OK) ");
} else {
        $output=$output."(OK) ";
}
$output = $output . sprintf("Connections: %d ", $conn);
if ($ConnCrit > 0) {
        ($conn > $ConnCrit) ? ($output = $output . "(Critical) ") :
                ($conn > $ConnWarn) ? ($output = $output . "(Warning) ") :
                        ($output = $output . "(OK) ");
} else {
        $output=$output."(OK) ";
}

# Main output
print "$output";

# Performance output
if ($perf) {;
        print " |";
        if ( $InCrit < 0 ) { printf(" In=%.2f;;;;",$inbit) }
        else { printf(" In=%.2f;%s;%s;;",$inbit,$InWarn,$InCrit) }
        if ( $OutCrit < 0 ) { printf(" Out=%.2f;;;;",$outbit) }
        else { printf(" Out=%.2f;%s;%s;;",$outbit,$OutWarn,$OutCrit) }
        if ( $ConnCrit < 0 ) { printf(" Conn=%d;;;;",$conn) }
        else { printf(" Conn=%d;%s;%s;;",$conn,$ConnWarn,$ConnCrit) }
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
        [-v], --debug
        [-f], --performance             (output Nagios performance data)
        [-T], --timeout <seconds>       (default is $TIMEOUT)
        [-S], --sleeptime <seconds>     (default is $sleeptime)
        [-C], --community <community>
        [-P], --port <snmp_port>        (default is $opt_P)
        [-V], --version <snmp_version>  (default is $opt_V)
        [-H], --host <ip>
        [-i], --in <warn:crit>          (bps)
        [-o], --out <warn:crit>         (bps)
        [-d], --device <ip>
        [-c], --connections <warn:crit>
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

