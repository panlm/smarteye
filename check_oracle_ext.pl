#!/usr/local/smarteye/perl/bin/perl
#check oracle kpi
#Last modified: 2011-12-21
#usage : ./check_oracle.pl -h                 
#author Tianbz

use DBI;
use Getopt::Std;

use vars qw($opt_H $opt_s $opt_u $opt_p $opt_k $opt_w $opt_c $opt_l $opt_h);
getopts("H:s:u:p:k:w:c:lh");

my $status_O = "OK";
my $status_W = "WARNNING";
my $status_C = "CRITICAL";
my $status_U = "UNKNOWN";
sub usage();

checkArgs();

my %oneOutPutKpi = (
        "lock" => [
			'select count(*) from v$lock',
			'lock count',
			'count'
		]
);

my $sql     = $oneOutPutKpi{$opt_k}[0];
my $desc    = $oneOutPutKpi{$opt_k}[1];
my $outname = $oneOutPutKpi{$opt_k}[2]; 
if(!$sql){
        message("kpi $opt_k not exists");
}

process();

sub process{
	my $rs = queryOneResult();
	if(!$opt_w && !$opt_c){
		print "$status_O - $rs $desc | $outname=$rs\;\;\n";
		exit(0);
	}
	if($opt_l){
		if($opt_w && $opt_c){
			if($opt_w < $opt_c){
                        	message('warning threshold could not < critical threshold' . " , but $opt_w < $opt_c" );
                	}
                        if($rs <= $opt_c){
                                print "$status_C - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
                        }elsif($rs <= $opt_w && $rs > $opt_c){
                                print "$status_W - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
                        }else{
                                print "$status_O - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
                        }
                }elsif(!$opt_w && $opt_c){
                        if($rs <= $opt_c){
                                print "$status_C - $rs $desc | $outname=$rs\;\;$opt_c\n";
                        }else{
                                print "$status_O - $rs $desc | $outname=$rs\;\;$opt_c\n";
                        }
                }elsif($opt_w && !$opt_c){
                        if($rs <= $opt_w){
                                print "$status_W - $rs $desc | $outname=$rs\;$opt_w\;\n";
                        }else{
                                print "$status_O - $rs $desc | $outname=$rs\;$opt_w\;\n";
                        }
                }	
	}else{
		if($opt_w && $opt_c){
			if($opt_w > $opt_c){
                        	message('warning threshold could not > critical threshold' . " , but $opt_w > $opt_c" );
                	}
			if($rs >= $opt_c){
				print "$status_C - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
			}elsif($rs >= $opt_w && $rs < $opt_c){
				print "$status_W - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
			}else{
				print "$status_O - $rs $desc | $outname=$rs\;$opt_w\;$opt_c\n";
			}			
		}elsif(!$opt_w && $opt_c){
			if($rs >= $opt_c){
				print "$status_C - $rs $desc | $outname=$rs\;\;$opt_c\n";
			}else{
				print "$status_O - $rs $desc | $outname=$rs\;\;$opt_c\n";
			}
		}elsif($opt_w && !$opt_c){
			if($rs >= $opt_w){
                                print "$status_W - $rs $desc | $outname=$rs\;$opt_w\;\n";
                        }else{
                                print "$status_O - $rs $desc | $outname=$rs\;$opt_w\;\n";
                        }
		}
	}
	exit(0);
}

sub queryOneResult{
	my $result = undef;
	my $dbh="";
        eval{
		$dbh = DBI->connect ("dbi:Oracle:host=$opt_H;sid=$opt_s", $opt_u, $opt_p , {RaiseError=>1,AutoCommit=>0});
	};
	if($@){
		my @ss = split("at ./check_oracle.pl" , $@);
		print("$status_C $ss[0]\n");
		exit(1);
	}
	my $sth=$dbh->prepare($sql);
        $sth->execute;
        while (@rs = $sth->fetchrow_array) {
                $result = $rs[0];
        }
        $sth -> finish();
        $dbh->disconnect();
	return $result;
}

sub message{
print $_[0] . "\n";
usage();
}

sub checkArgs{
	
	if($opt_h){
        	usage();
	}
	
	if(!$opt_H){
		message("lack parameter -H");
	}
	
	if(!$opt_s){
                message("lack parameter -s");
        }
	
	if(!$opt_u){
                message("lack parameter -u");
        }
	
	if(!$opt_p){
                message("lack parameter -p");
        }

	if(!$opt_k){
                message("lack parameter -k");
        }
}

sub usage(){
print '
-h      : help
-H      : host
-s      : sid 
-u      : username
-p      : password
-W      : The Warning threshold 
-C      : The critical threshold
-l      : The warning or critical check is low limit check 
-k      : kpi name
	: k = lock : lock count
-----------------------------------------------------------------------------
example : ./check_oracle.pl -H 192.168.1.223 -s idc20 -u system -p idc20 -k lock -c 13 -w 11
WARNNING - 12 lock count | count=12;11;13
' . "\n";
exit(1);
}

