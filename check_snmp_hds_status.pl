#!/usr/local/smarteye/perl/bin/perl

use SNMP;

my $status_O = "OK";
my $status_W = "WARNNING";
my $status_C = "CRITICAL";
my $status_U = "UNKNOWN";

use vars qw($opt_H $opt_C $opt_V $opt_D $opt_p $opt_help $opt_K);

$opt_C = "public";
$opt_V = "1";
$opt_P = 161;

my %kpi = (
	0 => "Drive",
	1 => "SpareDrive",
	2 => "DataDrive",
	3 => "ENC",
	6 => "Warning",
	7 => "OtherController",
	8 => "UPS",
	9 => "Loop",
	10 => "Path",
	11 => "NASServer",
	12 => "NASPath",
	13 => "NASUPS",
	16 => "Battery",
	17 => "PowerSupply",
	18 => "AC",
	19 => "BK",
	20 => "Fan",
	21 => "AdditionalBattery",
	24 => "CacheMemory",
	25 => "SATASpareDrive",
	26 => "SATADataDrive",
	27 => "SENC",
	28 => "HostConnector",
	29 => "NNC",
	30 => "I/FBoard"
	);


use Getopt::Long;
my $args = GetOptions(
	"H=s" => \$opt_H,
	"C=s" => \$opt_C,
	"P=s" => \$opt_P,
	"V=s" => \$opt_V,
	"K=s" => \$opt_K,
	"help!" => \$opt_help
);

if($opt_help){
	print_help();
	exit(0);
}

if(!$opt_H){
	parameterError("-H");
}

my $snmp_session = new SNMP::Session (
    DestHost    => $opt_H,
    Community   => $opt_C,
    RemotePort  => $opt_p,
    Version     => $opt_V
);

my $outDesc = "";
my $outValue = "";
my $totalStatus = $status_O;

my ($status) = undef;
($status) = $snmp_session->get(
        [[".1.3.6.1.4.1.116.5.11.1.2.2.1" , 0]]
);

$len = length($status);

if($len eq 0){
	printf($status_U . "-Could not get data by snmp! \n");
	exit(0);
}

$addlen = 32 - $len;
$result = ("%b" , $status);

if($addlen gt 0){
	for($i = 0 ; $i < $addlen ; $i++){
		$result = "0".$result;
	}
}

if($opt_K eq 0 || $opt_K){
	$opt_K = $opt_K;
}elsif(!$opt_K){
	$opt_K = "0,1,2,3,6,7,8,9,10,11,12,13,16,17,18,19,20,21,24,25,26,27,28,29,30";
}
#if($opt ne 0 && !$opt_K){
#	#$kpis = $opt_K;
#	$opt_K = "0,1,2,3,6,7,8,9,10,11,12,13,16,17,18,19,20,21,24,25,26,27,28,29,30";	
#}
my @tempk = split("," , $opt_K);

my $flag = 0;
foreach my $key (@tempk) {
	if(exists $kpi{$key}){
		process(substr($result , $key , 1), $kpi{$key}."Status" , $kpi{$key} );
		$flag = 1;
	}
}
if(!$flag){
	printf("Parameter -K value does not exist! \n");
	print_help();
	exit(0);
}


sub process{
	my $statusValue = $_[0];
	my $outDescTemp = $_[1];
	my $outValueDesc = $_[2];
	
	if($statusValue eq "0"){
        	$outDesc = "$outDesc$outDescTemp is $status_O,";
        	$outValue = "$outValue$outValueDesc=$statusValue;;1;;; ";
	}else{
		$outDesc = "$outDesc$outDescTemp-$status_C,";
                $outValue = "$outValue$outValueDesc=$statusValue;;1;;; ";
		$totalStatus = $status_C;
	}
}

print $totalStatus . "-" .substr($outDesc , 0 , length($outDesc) - 1) ."|". $outValue;
print "\n";
sub print_help{
print "
   -C , --Community    : SNMP Community string
   -H , --Host         : Remote Host Address
   -P , --RemotePort   : snmp port , default 161
   -V , --snmp version : snmp Version ,default v1
   -K , --kpi          : Parameters separated by commas ; Such as (-K 0,1), OutPut is(Drive=....; SpareDrive=...) 
			0 drive status              
			1 spare drive status       
			2 data drive status         
			3 ENC status                
			6 warning status        
			7 Other controller status   
			8 UPS status          
			9 loop status               
			10 path status              
			11 NAS Server status       
			12 NAS Path status         
			13 NAS UPS status           
			16 battery status
			17 power supply status
			18 AC status
			19 BK status
			20 fan status
			21 additional battery status
			24 cache memory status
			25 SATA spare drive status
			26 SATA data drive status
			27 SENC status
			28 HostConnector status
			29 NNC status
			30 I/F board status
";
}

sub parameterError(){
	printf("equired parameter " . $_[0] . " format does not right!" . "\n");
	exit(1);
}
