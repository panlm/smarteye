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
# 1-Nov-2010 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my $InRateWarn = -1;
my $InRateCrit = -1;
my $OutRateWarn = -1;
my $OutRateCrit = -1;
my $InDiscardRateWarn = -1;
my $InDiscardRateCrit = -1;
my $OutDiscardRateWarn = -1;
my $OutDiscardRateCrit = -1;
my $InErrorRateWarn = -1;
my $InErrorRateCrit = -1;
my $OutErrorRateWarn = -1;
my $OutErrorRateCrit = -1;
my $InPktPsWarn = -1;
my $InPktPsCrit = -1;
my $OutPktPsWarn = -1;
my $OutPktPsCrit = -1;

my $debug = 0;
my $perf = 0;

use SNMP;
use Getopt::Long;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_n $opt_i $opt_o $opt_d $opt_D $opt_e $opt_E $opt_k $opt_K);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
$opt_n = "0";
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s
my $sleeptime = 50; # seconds

sub print_help ();
sub print_usage ();

my $tmp_dir = "/var/tmp";
$PROGNAME = "check_snmp_port";

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
        "n=s" => \$opt_n, "SwitchPort=s"     => \$opt_n,
        "i=s" => \$opt_i, "InRate=s"         => \$opt_i,
        "o=s" => \$opt_o, "OutRate=s"        => \$opt_o,
        "d=s" => \$opt_d, "InDiscardRate=s"  => \$opt_d,
        "D=s" => \$opt_D, "OutDiscardRate=s" => \$opt_D,
        "e=s" => \$opt_e, "InErrorRate=s"    => \$opt_e,
        "E=s" => \$opt_E, "OutErrorRate=s"   => \$opt_E,
        "k=s" => \$opt_k, "InPktPs=s"        => \$opt_k,
        "K=s" => \$opt_K, "OutPktPs=s"       => \$opt_K
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
if ($opt_i) { 
        ($InRateWarn, $InRateCrit) = split /:/, $opt_i;

        ($InRateWarn && $InRateCrit) || usage ("missing value -i <warn:crit>\n");

        ($InRateWarn =~ /^\d{1,3}$/ && $InRateWarn > 0 && $InRateWarn <= 100) &&
        ($InRateCrit =~ /^\d{1,3}$/ && $InRateCrit > 0 && $InRateCrit <= 100) ||
                usage("Invalid value: -i <warn:crit> (In Rate Percent): $opt_i\n");

        ($InRateCrit > $InRateWarn) || 
                usage("critical (-i $opt_i <warn:crit>) must be > warning\n");
}
print "InRateWarn:$InRateWarn; InRateCrit:$InRateCrit\n" if $debug;
if ($opt_o) { 
        ($OutRateWarn, $OutRateCrit) = split /:/, $opt_o;

        ($OutRateWarn && $OutRateCrit) || usage ("missing value -o <warn:crit>\n");

        ($OutRateWarn =~ /^\d{1,3}$/ && $OutRateWarn > 0 && $OutRateWarn <= 100) &&
        ($OutRateCrit =~ /^\d{1,3}$/ && $OutRateCrit > 0 && $OutRateCrit <= 100) ||
                usage("Outvalid value: -o <warn:crit> (Out Rate Percent): $opt_o\n");

        ($OutRateCrit > $OutRateWarn) || 
                usage("critical (-o $opt_o <warn:crit>) must be > warning\n");
}
print "OutRateWarn:$OutRateWarn; OutRateCrit:$OutRateCrit\n" if $debug;
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
if ($opt_k) { 
        ($InPktPsWarn, $InPktPsCrit) = split /:/, $opt_k;

        ($InPktPsWarn && $InPktPsCrit) || usage ("missing value -k <warn:crit>\n");

        ($InPktPsWarn =~ /^\d{1,5}$/ && $InPktPsWarn > 0) &&
        ($InPktPsCrit =~ /^\d{1,5}$/ && $InPktPsCrit > 0) ||
                usage("Invalid value: -k <warn:crit> (In Packet Per Second): $opt_k\n");

        ($InPktPsCrit > $InPktPsWarn) || 
                usage("critical (-k $opt_k <warn:crit>) must be > warning\n");
}
print "InPktPsWarn:$InPktPsWarn; InPktPsCrit:$InPktPsCrit\n" if $debug;
if ($opt_K) { 
        ($OutPktPsWarn, $OutPktPsCrit) = split /:/, $opt_K;

        ($OutPktPsWarn && $OutPktPsCrit) || usage ("missing value -K <warn:crit>\n");

        ($OutPktPsWarn =~ /^\d{1,5}$/ && $OutPktPsWarn > 0) &&
        ($OutPktPsCrit =~ /^\d{1,5}$/ && $OutPktPsCrit > 0) ||
                usage("Invalid value: -K <warn:crit> (Out Packet Per Second): $opt_K\n");

        ($OutPktPsCrit > $OutPktPsWarn) || 
                usage("critical (-K $opt_K <warn:crit>) must be > warning\n");
}
print "OutPktPsWarn:$OutPktPsWarn; OutPktPsCrit:$OutPktPsCrit\n" if $debug;

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_H,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

if ( ! $opt_n ) {
    my ($ifidx, $ifdesc, $iftype) = undef;
    ($ifidx, $ifdesc, $iftype) = $snmp_session->bulkwalk( 0, 3,
        [['ifIndex'],
         ['ifDescr'],
         ['ifType']]
    );
    check_for_errors();
    
    my ($string, $string2, $found) = undef;
    my $i = 0; 
    for ( $i = 0; $i <= $#$iftype; $i++ ) {
        $string = scalar(@$iftype[$i]->val);
        $string2 = scalar(@$ifdesc[$i]->val);
        printf "ifType: %s\t|ifDescr: %s\n",$string,$string2 if $debug; 
        if ( $string == 6 ) {
            # IF-MIB::ifType.2 = INTEGER: ethernetCsmacd(6)
            if ( $string2 !~ /(WAN|TAP)/ ) {
                $found = 1;
                last;
            }
        }
    }
    printf "i:$i\n" if $debug;
    if ( ! $found ) {
        printf "label not found\n";
        exit;
    }
    if ( ! $opt_n ) {
        $opt_n = scalar(@$ifidx[$i]->val);
    }
}

printf "port number:$opt_n\n" if $debug;

my $history_file_name = $PROGNAME . "_" . $opt_H . "_" . $opt_n;
print "$tmp_dir/$history_file_name\n" if $debug;

my ($last_check_time, $tmp_speed, $tmp_in, $tmp_inupkt, $tmp_out, $tmp_outupkt, $tmp_indiscard, $tmp_outdiscard, $tmp_inerror, $tmp_outerror) = undef;
if ( open(FILE,"$tmp_dir/$history_file_name") ) {;
    $last_check_time = <FILE>; chomp($last_check_time);
    $tmp_speed = <FILE>;       chomp($tmp_speed);
    $tmp_in = <FILE>;          chomp($tmp_in);
    $tmp_inupkt = <FILE>;      chomp($tmp_inupkt);
    $tmp_out = <FILE>;         chomp($tmp_out);
    $tmp_outupkt = <FILE>;     chomp($tmp_outupkt);
    $tmp_indiscard = <FILE>;   chomp($tmp_indiscard);
    $tmp_outdiscard = <FILE>;  chomp($tmp_outdiscard);
    $tmp_inerror = <FILE>;     chomp($tmp_inerror);
    $tmp_outerror = <FILE>;    chomp($tmp_outerror);
    close(FILE);
} else {
    # retrieve the data from the remote host
    $last_check_time = time();
    ($tmp_speed, $tmp_in, $tmp_inupkt, $tmp_out, $tmp_outupkt, $tmp_indiscard, $tmp_outdiscard, $tmp_inerror, $tmp_outerror) = $snmp_session->get([
        ['ifSpeed',$opt_n],
        ['ifInOctets',$opt_n],
        ['ifInUcastPkts',$opt_n],
        ['ifOutOctets',$opt_n],
        ['ifOutUcastPkts',$opt_n],
        ['ifInDiscards',$opt_n],
        ['ifOutDiscards',$opt_n],
        ['ifInErrors',$opt_n],
        ['ifOutErrors',$opt_n]
    ]);
    check_for_errors();

    # need to sleep to get delta
    sleep $sleeptime;

}

print "time\t speed\t\tin\t\tinupkt\t\tout\t\toutupkt\t\tindiscard\toutdiscard\tinerror\tinerror\n" if $debug;
print "$last_check_time\t $tmp_speed\t$tmp_in\t$tmp_inupkt\t$tmp_out\t$tmp_outupkt\t$tmp_indiscard\t\t$tmp_outdiscard\t\t$tmp_inerror\t$tmp_outerror \n" if $debug;

my ($check_time, $speed, $in, $inupkt, $out, $outupkt, $indiscard, $outdiscard, $inerror, $outerror) = undef;
# retrieve the data from the remote host
$check_time = time();
($speed, $in, $inupkt, $out, $outupkt, $indiscard, $outdiscard, $inerror, $outerror) = $snmp_session->get(
  [['ifSpeed',$opt_n],
   ['ifInOctets',$opt_n],
   ['ifInUcastPkts',$opt_n],
   ['ifOutOctets',$opt_n],
   ['ifOutUcastPkts',$opt_n],
   ['ifInDiscards',$opt_n],
   ['ifOutDiscards',$opt_n],
   ['ifInErrors',$opt_n],
   ['ifOutErrors',$opt_n]]
);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$speed\n";
    print FILE "$in\n";
    print FILE "$inupkt\n";
    print FILE "$out\n";
    print FILE "$outupkt\n";
    print FILE "$indiscard\n";
    print FILE "$outdiscard\n";
    print FILE "$inerror\n";
    print FILE "$outerror\n";
    close(FILE);
}

print "time\t speed\t\tin\t\tinupkt\t\tout\t\toutupkt\t\tindiscard\toutdiscard\tinerror\tinerror\n" if $debug;
print "$check_time\t $speed\t$in\t$inupkt\t$out\t$outupkt\t$indiscard\t\t$outdiscard\t\t$inerror\t$outerror \n" if $debug;

alarm (0); # Done with network

# deal wrap
if ($in < $tmp_in ) {
    $in = 4294967295 + $in +1;
}
if ($out < $tmp_out ) {
    $out = 4294967295 + $out +1;
}
if ($inupkt < $tmp_inupkt ) {
    $inupkt = 4294967295 + $inupkt +1;
}
if ($outupkt < $tmp_outupkt ) {
    $outupkt = 4294967295 + $outupkt +1;
}

#debug ifInOctets
#my $current = `/bin/date +"%Y%m%d %H%M%S"`;
#chomp $current;
#open( FILE, '>>', '/tmp/switchport-2.log' );
#print FILE "$current\t$opt_H\t$opt_n\t$tmp_in\t$in";
#print FILE "\n";
#close FILE;

# Calculate Here
my ($inbit, $outbit, $inrate, $outrate, $inpkt, $outpkt, $inpktps, $outpktps, $indiscardrate, $outdiscardrate, $inerrorrate, $outerrorrate) = undef;
$inbit = ( $in - $tmp_in ) * 8 / ( $check_time - $last_check_time ) ;
$outbit = ( $out - $tmp_out ) * 8 / ( $check_time - $last_check_time ) ;
if ( $speed ) {
    $inrate = $inbit / $speed * 100 ;
    $outrate = $outbit / $speed * 100 ;
} else {
    $inrate = 0;
    $outrate = 0;
}
$inpkt = $inupkt - $tmp_inupkt ;
$outpkt = $outupkt - $tmp_outupkt ;
if ( ! $inpkt ) { $inpkt = $inpkt + 1; }
if ( ! $outpkt ) { $outpkt = $outpkt + 1; }
$inpktps = $inpkt / ( $check_time - $last_check_time ) ;
$outpktps = $outpkt / ( $check_time - $last_check_time ) ;
$indiscardrate = ( $indiscard - $tmp_indiscard ) / $inpkt * 100 ;
$outdiscardrate = ( $outdiscard - $tmp_outdiscard ) / $outpkt * 100 ;
$inerrorrate = ( $inerror - $tmp_inerror ) / $inpkt * 100 ;
$outerrorrate = ( $outerror - $tmp_outerror ) / $outpkt * 100 ;

print "inbit:$inbit, outbit:$outbit, inrate:$inrate, outrate:$outrate, inpktps:$inpktps, outpktps:$outpktps, indiscardrate:$indiscardrate, outdiscardrate:$outdiscardrate, inerrorrate:$inerrorrate, outerrorrate:$outerrorrate\n" if $debug;

#debug ifInOctets
#print FILE "\t$inbit\t$tmp_out\t$out\t$outbit\n";
#close FILE;

# Threshold checks
my $output = undef;

$output = $output . sprintf("In: %.2fbps ", $inbit);
$output = $output . sprintf("Out: %.2fbps ", $outbit);
$output = $output . sprintf("InRate: %.2f%% ", $inrate);
if ($InRateCrit > 0) {
        ($inrate > $InRateCrit) ? ($output = $output . "(Critical) ") :
                ($inrate > $InRateWarn) ? ($output = $output . "(Warning) ") : 
                        ($output = $output."(OK) ");
} else {
        $output=$output."(OK) ";
}
$output = $output . sprintf("OutRate: %.2f%% ", $outrate);
if ($OutRateCrit > 0) {
        ($outrate > $OutRateCrit) ? ($output = $output . "(Critical) ") :
                ($outrate > $OutRateWarn) ? ($output = $output . "(Warning) ") : 
                        ($output = $output . "(OK) ");
} else {
        $output=$output."(OK) ";
}
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
$output = $output . sprintf("InPktPs: %.2fpps ", $inpktps);
if ($InPktPsCrit > 0) {
        ($inpktps > $InPktPsCrit) ? ($output = $output . "(Critical) ") :
                ($inpktps > $InPktPsWarn) ? ($output = $output . "(Warning) ") : 
                        ($output = $output."(OK) ");
} else {
        $output=$output."(OK) ";
}
$output = $output . sprintf("OutPktPs: %.2fpps ", $outpktps);
if ($OutPktPsCrit > 0) {
        ($outpktps > $OutPktPsCrit) ? ($output = $output . "(Critical) ") :
                ($outpktps > $OutPktPsWarn) ? ($output = $output . "(Warning) ") : 
                        ($output = $output."(OK) ");
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
    if ($InRateCrit < 0) { printf(" InRate=%.2f;;;;", $inrate) }
    else { printf(" InRate=%.2f;%d;%d;;", $inrate,$InRateWarn,$InRateCrit) }
    if ($OutRateCrit < 0) { printf(" OutRate=%.2f;;;;", $outrate) }
    else { printf(" OutRate=%.2f;%d;%d;;", $outrate,$OutRateWarn,$OutRateCrit) }
    if ($InDiscardRateCrit < 0) { printf(" InDiscardRate=%.2f;;;;", $indiscardrate) }
    else { printf(" InDiscardRate=%.2f;%d;%d;;", $indiscardrate,$InDiscardRateWarn,$InDiscardRateCrit) }
    if ($OutDiscardRateCrit < 0) { printf(" OutDiscardRate=%.2f;;;;", $outdiscardrate) }
    else { printf(" OutDiscardRate=%.2f;%d;%d;;", $outdiscardrate,$OutDiscardRateWarn,$OutDiscardRateCrit) }
    if ($InErrorRateCrit < 0) { printf(" InErrorRate=%.2f;;;;", $inerrorrate) }
    else { printf(" InErrorRate=%.2f;%d;%d;;", $inerrorrate,$InErrorRateWarn,$InErrorRateCrit) }
    if ($OutErrorRateCrit < 0) { printf(" OutErrorRate=%.2f;;;;", $outerrorrate) }
    else { printf(" OutErrorRate=%.2f;%d;%d;;", $outerrorrate,$OutErrorRateWarn,$OutErrorRateCrit) }
    if ($InPktPsCrit < 0) { printf(" InPktPs=%.2f;;;;", $inpktps) }
    else { printf(" InPktPs=%.2f;%d;%d;;", $inpktps,$InPktPsWarn,$InPktPsCrit) }
    if ($OutPktPsCrit < 0) { printf(" OutPktPs=%.2f;;;;", $outpktps) }
    else { printf(" OutPktPs=%.2f;%d;%d;;", $outpktps,$OutPktPsWarn,$OutPktPsCrit) }
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
    [-n], --SwitchPort <switchport> (default 2)
    [-i], --InRate <warn:crit> percent
    [-o], --OutRate <warn:crit> percent
    [-d], --InDiscardRate <warn:crit> percent
    [-D], --OutDiscardRate <warn:crit> percent
    [-e], --InErrorRate <warn:crit> percent
    [-E], --OutErrorRate <warn:crit> percent
    [-k], --InPktPs <warn:crit>
    [-K], --OutPktPs <warn:crit>
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

