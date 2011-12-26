#!/usr/local/groundwork/perl/bin/perl -w
#
# $Id$
#
use strict;
use Time::HiRes qw(gettimeofday);

my $opt_debug = 0;
my $opt_help = undef;
my $opt_ext = undef;
my $opt_count = 10;
my $opt_sleep = 5;
my $opt_file = undef; 
my $opt_output = "/tmp/perf_out.csv";
sub execCommand;

use Getopt::Long;

Getopt::Long::Configure('bundling');
my $status = GetOptions ( 
	"d"	=> \$opt_debug, "debug"		=> \$opt_debug,
	"h"	=> \$opt_help, "opt_help"	=> \$opt_help, 
	"e=s"   => \$opt_ext, "ext"		=> \$opt_ext,
	"c=s"	=> \$opt_count, "count" 	=> \$opt_count,
	"s=s"	=> \$opt_sleep, "sleep" 	=> \$opt_sleep,
	"f=s"   => \$opt_file,  "file"		=> \$opt_file,
	"o=s"   => \$opt_output,  "ofile"	=> \$opt_output,
);

if($opt_help){
	print "test_pressure.pl plugin is use to test the plugin's performance\n
-d|--debug	debug mode
-h|--help	plugin help
-e|--ext	the command line of the test plugin	
-c|--count	test times
-s|--sleep	test per plugin sleep time
-f|--file	the command list file(format:kpi description = command line)
		kpi description and command line splid by \"=\"
-o|--output	performance test output file path\n
Expale ./test_pressure.pl -e '/usr/local/smarteye/nagios/libexec/check_tcp -H localhost -p 22' -c 10000 -s 0\n
Expale ./test_pressure.pl -f '/usr/local/smarteye/nagios/libexec/comman_list.txt -H localhost -p 22' -c 10000 -s 0\n\n";
exit 0;
}
if(!$opt_file && !$opt_ext){
    print "missing param\n";
    exit 1;
}

#generate the csv head
my $output = "name";
foreach(1..$opt_count){
    $output .= ",times" . $_ . "(s)"; 
}
$output .= ",max(s),min(s),avg(s),total(s),ok,warming,critical,unknow";
qx(echo "$output" > $opt_output);


if($opt_file){
    if(!open(EXTFILE, '<', $opt_file)){
	print "Can not open extenal command file, file= " . $opt_file . "\n"; 
	exit 1;
    }
    while (my $command = <EXTFILE>){
    	if($command =~ /^(.*)=(.*)$/){
	    my ($command_name,$command_line) = ($1,$2);
	    $command_name =~ s/(^\s+|\s+$)//g;
	    $command_line =~ s/(^\s+|\s+$)//g;
	    $output = execCommand($command_name,$command_line,$opt_sleep,$opt_count);
	    qx(echo $output >> $opt_output);
	}else{
	    print "warning,format parttern is error. please check,command line:\n" . $command . "\n";
	}
    }
    close(EXTFILE);
    exit 0;
}

if($opt_ext){
    $output = execCommand("extenal command",$opt_ext,$opt_sleep,$opt_count);
    qx(echo $output >> $opt_output);
    exit 0;
}



sub execCommand(@){
    my $command_name	= $_[0];
    my $command_line	= $_[1];
    my $sleep_time	= $_[2];
    my $run_times	= $_[3];
    my $output = $command_name; 
    my ($start,$end) = (0,0);
    my ($ok,$warn,$crit,$unknow) = (0,0,0,0);
    my ($max,$min,$total) = (0,0,0);
    print "######################KPI ($command_name) performance test####################\n";
    foreach(1..$run_times){
	my $use_time = 0;
	$start =  gettimeofday();
	my $plugin_output = qx($command_line); 
	my $result = $? >>8;	
	if($result == 0){
	    $ok ++;
	}elsif($result ==  1){
	    $warn ++;
	}elsif($result == 2){
	    $crit ++;
	}else{
	    $unknow ++;
	}
	$end = gettimeofday();
	$use_time = $end - $start;
	$output .= "," . $use_time;
	$total = $total + $use_time;
	if($_ == 1){
	    $max = $use_time;
	    $min = $use_time;
	}else{
	    if($max < $use_time){
		$max = $use_time;
	    } 
	    if($min > $use_time){
		$min = $use_time;
	    }
	}	
	print "usetime:$use_time, output:$plugin_output" if $opt_debug;
	sleep $sleep_time;
    }
    print "Summary:run times: $run_times,max: $max(s), min: $min(s), avg: " . ($total/$run_times) . "(s), total: $total(s),
	OK: $ok, warning: $warn, critical: $crit, unknow: $unknow\n\n";
    $output .= ",$max,$min," . ($total/$run_times) . ",$total"; 
    $output .= ",$ok,$warn,$crit,$unknow";
    return $output;
}

















