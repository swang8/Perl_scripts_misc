#!/usr/bin/perl -w
use strict;


my $sUsage = qq(
***********************************************************************************************************
This script is designed to convert Stakman scale rust phenotypes to linear scores.

Usage:  perl   $0   your_phenotype_file.txt  >your_linear_scores.txt

This script would ONLY take TAB-delimited text file.
This script assume the first row and first column are information about traits or individuals. 
The score calculation would start from the sencond colun and the second row.

The transformation table is designed as the following:
		'0'    => 0,
		'1-'   => 1,
		'1'    => 2,
		'1+'   => 3,
		'2-'   => 4,
		'2'    => 5,
		'2+'   => 6,
		'3-'   => 7,
		'3'    => 8,
		'3+'   => 9,
		';'    => 0,
		'4'    => 9,
		'C'    => -1,  # ignored
		"N"    => -1,  # ignored
		"X-"   => 4,
		"Y-"   => 4,
		"Z-"   => 4,
		"X"    => 5,
		"Y"    => 5,
		"Z"    => 5,
		"X+"   => 6,
		"Y+"   => 6,
		"Z+"   => 6,
		"S"    => 8,
		"SLIF" => 9
		
!! Phenotypes that are not in the transformation table will be ignored.

The calculation uses all the information of the phenotype, while some other methods are taking only the first and the last.
For example: the score for pheontype ";3+3Z" is calculated as:
 ;       3+      3       Z
 |       |       |       |
(0 * 4 + 9 * 3 + 8 * 2 + 5 * 1) / (4+3+2+1) = 4.8

Author: Shichen Wang, wangsc\@ksu.edu

***********************************************************************************************************
);
die $sUsage unless @ARGV;

my $file = shift;

open(IN, $file) or die $!;

while(<IN>){
		if($. == 1){print $_; next}
		chomp;
		my @t = split /\t/, $_;
		map{$t[$_] = &calculate_linear_score($t[$_]) }1..$#t;
		print join("\t", @t), "\n"
}



sub calculate_linear_score{
	my %linear_score = (
		'0'    => 0,
		'1-'   => 1,
		'1'    => 2,
		'1+'   => 3,
		'2-'   => 4,
		'2'    => 5,
		'2+'   => 6,
		'3-'   => 7,
		'3'    => 8,
		'3+'   => 9,
		';'    => 0,
		'4'    => 9,
		'C'    => -1,  # ignored
		"N"    => -1,  # ignored
		"X-" => 4,
		"Y-" => 4,
		"Z-" => 4,
		"X"  => 5,
		"Y"  => 5,
		"Z"  => 5,
		"X+" => 6,
		"Y+" => 6,
		"Z+" => 6,
		"S"  => 8,
		"SLIF" => 9,
		);
  my $pheno = shift;
  $pheno =~ s/\s//g;     # remove blank space
  $pheno =~ s/\++/\+/g;  # collapse multuple '+' to one '+'
  $pheno =~ s/\-+/-/g;   # collapse multuple '-' to one '-'
  $pheno = uc($pheno);
  
  my @arr = ("");
  foreach((split //, $pheno)){
  	last if (/\//);
  	if(not exists $linear_score{$_}){
  		$arr[-1] .= $_
  	}else{
  		push @arr, $_
  	}
  }
  print STDERR $pheno, "\t", join("*", @arr[1..$#arr]), "\n"; 
  
  my @p = ();
  foreach (@arr[1..$#arr]){
  	unless(exists $linear_score{$_}){
  		print STDERR "No score for \"$_\"! Maybe a typo?\n";
  		print STDERR "This score \"$_\" will be ignored\n";
  		next;
  	}
  	next if $linear_score{$_}  < 0; # skip
  	
  	push @p , $_;
  }
  
  print STDERR "For phehotype \"$pheno\", these info ". join("*", @p) . " were used to calcualte the linear score.\n";
  
  if (@p == 0){
  	print STDERR "Something is wrong with the phenotype string $pheno !!\n";
  	return "NA"
  }
  my $score = 0;
  map{ $score += (scalar @p - $_) * $linear_score{$p[$_]}  }0..$#p;
  $score = $score / ((scalar @p) * (scalar @p + 1) / 2);
  print STDERR "For phehotype \"$pheno\", the linear score is $score.\n";
  return $score;
}


