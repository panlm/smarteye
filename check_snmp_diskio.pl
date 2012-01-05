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
# 22-Dec-2012 - stevenpan@gmail.com
#        Initial revision
#
use strict;

my $ReadByteWarn = -1;
my $ReadByteCrit = -1;
my $WriteByteWarn = -1;
my $WriteByteCrit = -1;

my $debug = 0;
my $perf = 0;

#sysUpTimeInstance
my $uptimeoid = ".1.3.6.1.2.1.1.3.0";

use SNMP;
use Getopt::Long;
use Time::HiRes qw(time);
use vars qw($opt_h $opt_v $opt_C $opt_P $opt_V $opt_f);
use vars qw($opt_H $opt_l $opt_r $opt_w);
$opt_C = "public";
$opt_P = 161;
$opt_V = "2c";
# Watch out for this: snmpd updates every 5 secs by default
use vars qw($PROGNAME);
use lib "/usr/local/groundwork/nagios/libexec";
use utils qw($TIMEOUT %ERRORS &print_revision &support &usage);
$TIMEOUT=60; # default 15s
my $sleeptime = 10; # seconds

sub print_help ();
sub print_usage ();

my $tmp_dir = "/var/tmp";
$PROGNAME = "check_snmp_diskio";

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
        "l=s" => \$opt_l, "label=s"          => \$opt_l,
        "r=s" => \$opt_r, "ReadByte=s"       => \$opt_r,
        "w=s" => \$opt_w, "WriteByte=s"      => \$opt_w
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
if ($opt_r) { 
        ($ReadByteWarn, $ReadByteCrit) = split /:/, $opt_r;

        ($ReadByteWarn && $ReadByteCrit) || usage ("missing value -i <warn:crit>\n");

        ($ReadByteWarn =~ /^\d{1,3}$/ && $ReadByteWarn > 0 && $ReadByteWarn <= 100) &&
        ($ReadByteCrit =~ /^\d{1,3}$/ && $ReadByteCrit > 0 && $ReadByteCrit <= 100) ||
                usage("Invalid value: -i <warn:crit> (ReadByte): $opt_r\n");

        ($ReadByteCrit > $ReadByteWarn) || 
                usage("critical (-i $opt_r <warn:crit>) must be > warning\n");
}
print "ReadByteWarn:$ReadByteWarn; ReadByteCrit:$ReadByteCrit\n" if $debug;
if ($opt_w) { 
        ($WriteByteWarn, $WriteByteCrit) = split /:/, $opt_w;

        ($WriteByteWarn && $WriteByteCrit) || usage ("missing value -o <warn:crit>\n");

        ($WriteByteWarn =~ /^\d{1,3}$/ && $WriteByteWarn > 0 && $WriteByteWarn <= 100) &&
        ($WriteByteCrit =~ /^\d{1,3}$/ && $WriteByteCrit > 0 && $WriteByteCrit <= 100) ||
                usage("Outvalid value: -o <warn:crit> (WriteByte): $opt_w\n");

        ($WriteByteCrit > $WriteByteWarn) || 
                usage("critical (-o $opt_w <warn:crit>) must be > warning\n");
}
print "WriteByteWarn:$WriteByteWarn; WriteByteCrit:$WriteByteCrit\n" if $debug;
if (!$opt_l) { die "-l <disk_label> is required\n" }

print "timeout:$TIMEOUT sleeptime:$sleeptime\n" if $debug;

# Get the kernel/system statistic values from SNMP
alarm ( $TIMEOUT ); # Don't hang Nagios
my $snmp_session = new SNMP::Session (
    DestHost   => $opt_H,
    Community  => $opt_C,
    RemotePort => $opt_P,
    Version    => $opt_V
);

my ($diskioidx, $diskiodev) = undef;
($diskioidx, $diskiodev) = $snmp_session->bulkwalk( 0, 2, [
    ['.1.3.6.1.4.1.2021.13.15.1.1.1'],
    ['.1.3.6.1.4.1.2021.13.15.1.1.2']
]);
check_for_errors();

my ($idx, $string, $found) = undef;
my $i = 0;
for ( $i = 0; $i <= $#$diskioidx; $i++ ) {
    $string = scalar(@$diskiodev[$i]->val);
    printf "disk_label: %s\n",$i,$string if $debug;
    if ( $string eq "$opt_l" ) {
        $found = 1;
        last;
    }
}
if ( ! $found ) {
    printf "label not found\n";
    exit (2);
} else {
    $idx = scalar(@$diskioidx[$i]->val)
}
print "idx:$idx\n" if $debug;

my $history_file_name = $PROGNAME . "_" . $opt_H . "_" . $opt_l ;
print "$tmp_dir/$history_file_name\n" if $debug;

my ($last_check_time, $tmp_readbyte, $tmp_writebyte, $tmp_read, $tmp_write) = undef;
if ( open(FILE,"$tmp_dir/$history_file_name") ) {;
    $last_check_time = <FILE>; chomp($last_check_time);
    $tmp_readbyte = <FILE>;    chomp($tmp_readbyte);
    $tmp_writebyte = <FILE>;   chomp($tmp_writebyte);
    $tmp_read = <FILE>;        chomp($tmp_read);
    $tmp_write = <FILE>;       chomp($tmp_write);
    close(FILE);
} else {
    ($last_check_time, $tmp_readbyte, $tmp_writebyte, $tmp_read, $tmp_write) = $snmp_session->get([
        [$uptimeoid],
        ['.1.3.6.1.4.1.2021.13.15.1.1.3',$idx],
        ['.1.3.6.1.4.1.2021.13.15.1.1.4',$idx],
        ['.1.3.6.1.4.1.2021.13.15.1.1.5',$idx],
        ['.1.3.6.1.4.1.2021.13.15.1.1.6',$idx]
    ]);
    check_for_errors();

    # need to sleep to get delta
    sleep $sleeptime;
}

print "date\t readbyte\t writebyte\t read\t write\n" if $debug;
print "$last_check_time\t $tmp_readbyte\t $tmp_writebyte\t $tmp_read\t $tmp_write\n" if $debug;

my ($check_time, $readbyte, $writebyte, $read, $write) = undef;
($check_time, $readbyte, $writebyte, $read, $write) = $snmp_session->get([
    [$uptimeoid],
    ['.1.3.6.1.4.1.2021.13.15.1.1.3',$idx],
    ['.1.3.6.1.4.1.2021.13.15.1.1.4',$idx],
    ['.1.3.6.1.4.1.2021.13.15.1.1.5',$idx],
    ['.1.3.6.1.4.1.2021.13.15.1.1.6',$idx]
]);
check_for_errors();

# save data to history file
if ( open(FILE, ">$tmp_dir/$history_file_name") ) {
    print FILE "$check_time\n";
    print FILE "$readbyte\n";
    print FILE "$writebyte\n";
    print FILE "$read\n";
    print FILE "$write\n";
    close(FILE);
}

print "date\t readbyte\t writebyte\t read\t write\n" if $debug;
print "$check_time\t $readbyte\t $writebyte\t $read\t $write\n" if $debug;

alarm (0); # Done with network

# deal reboot
if ( $last_check_time gt $check_time ) {
    exit (0);
}

# deal wrap
if ($readbyte < $tmp_readbyte ) { $readbyte = 4294967295 + $readbyte +1; }
if ($writebyte < $tmp_writebyte ) { $writebyte = 4294967295 + $writebyte +1; }
if ($read < $tmp_read ) { $read = 4294967295 + $read +1; }
if ($write < $tmp_write ) { $write = 4294967295 + $write +1; }

# Calculate Here
my ($readbyterate, $writebyterate, $readrate, $writerate, $delta) = undef;
$delta = ( $check_time - $last_check_time ) / 100 ; print "delta: $delta\n" if $debug ;
$readbyterate = ( $readbyte - $tmp_readbyte ) / $delta / 1024 ;
$writebyterate = ( $writebyte - $tmp_writebyte ) / $delta / 1024 ;
$readrate = ( $read - $tmp_read ) / $delta ;
$writerate = ( $write - $tmp_write ) / $delta ;

print "readbyterate: $readbyterate\n" if $debug;
print "writebyterate: $writebyterate\n" if $debug;
print "readrate: $readrate\n" if $debug;
print "writerate: $writerate\n" if $debug;

# Threshold checks
my $output = undef;

$output = $output . sprintf("ReadKB/s: %.2f ", $readbyterate);
$output = $output . sprintf("WriteKB/s: %.2f ", $writebyterate);
$output = $output . sprintf("Read/s: %.2f ", $readrate);
$output = $output . sprintf("Write/s: %.2f ", $writerate);
#$output = $output . sprintf("InRate: %.2f%% ", $inrate);
#if ($InRateCrit > 0) {
#        ($inrate > $InRateCrit) ? ($output = $output . "(Critical) ") :
#                ($inrate > $InRateWarn) ? ($output = $output . "(Warning) ") : 
#                        ($output = $output."(OK) ");
#} else {
#        $output=$output."(OK) ";
#}
#$output = $output . sprintf("OutRate: %.2f%% ", $outrate);
#if ($OutRateCrit > 0) {
#        ($outrate > $OutRateCrit) ? ($output = $output . "(Critical) ") :
#                ($outrate > $OutRateWarn) ? ($output = $output . "(Warning) ") : 
#                        ($output = $output . "(OK) ");
#} else {
#        $output=$output."(OK) ";
#}

# Main output
print "$output";

# Performance output
if ($perf) {;
        print " |";
        printf(" ReadKB=%.2f;;;;",$readbyterate);
        printf(" WriteKB=%.2f;;;;",$writebyterate);
        printf(" Read=%.2f;;;;",$readrate);
        printf(" Write=%.2f;;;;",$writerate);
#        if ($InRateCrit < 0) { printf(" InRate=%.2f;;;;", $inrate) }
#        else { printf(" InRate=%.2f;%d;%d;;", $inrate,$InRateWarn,$InRateCrit) }
#        if ($OutRateCrit < 0) { printf(" OutRate=%.2f;;;;", $outrate) }
#        else { printf(" OutRate=%.2f;%d;%d;;", $outrate,$OutRateWarn,$OutRateCrit) }
}

print "\n";

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
        [-l], --label <disk_label>
        [-r], --ReadByte <warn:crit>
        [-w], --WriteByte <warn:crit>
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

