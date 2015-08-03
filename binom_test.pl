#!/usr/bin/perl -w 
use strict;
use PDL::Stats::Basic;

my $file = shift or die "perl $0 <file>\n";

open (IN, $file) or die "$!\n";
my $n = 0;
while (<IN>){
	chomp;
	my @t = split /\s+/, $_; 
	if(@t < 10){print $_, "\n"; next}
    $n++;
	if($n==1){print $_, "\n"; next}
	my $count_A = 0;
	my $count_B = 0;
	map{
		$count_A++ if /A/;
		$count_B++ if /B/;
	}@t[1..$#t];
	
	my $p1 = binomial_test($count_A>$count_B?$count_A:$count_B, $count_A+$count_B, 0.4);
	my $p2 = binomial_test($count_A>$count_B?$count_A:$count_B, $count_A+$count_B, 0.5);
	my $p3 = binomial_test($count_A>$count_B?$count_A:$count_B, $count_A+$count_B, 0.6);
	if($p1 > 0.05 or $p2 > 0.05  or $p3 > 0.05 ){print join("\t", @t), "\n"}
	else{print STDERR join("\t", ($t[0], $count_A, $count_B)),"\n"}
}
close IN;
