#!/usr/bin/perl -w
use strict;

my $sUsage = "perl $0 hmp_file \n";
die $sUsage unless @ARGV;

my $file = shift or die $sUsage;

my $ped = $file . ".ped";
open(PED, ">$ped") or die $!;
my $map = $file . ".map";
open(MAP, ">$map") or die $!;

open(IN, $file) or die $!;

my %res;

my @pos;

my @arr;

while(<IN>){
	chomp;
	my @t = split /\s+/,$_; 
	if(/^rs/){
		@arr = @t;
		next;
	}
    my $chr = $t[2];
    $chr=~s/Chr//g; $chr +=0;
	push @pos, join("\t", $chr, $t[0], 0, $t[3]);	
	map{
		if(length $t[$_] == 1) {
			push @{$res{$arr[$_]}}, join(" ", @t[$_, $_]);
		}
		else{
			push @{$res{$arr[$_]}}, join(" ", (split //, $t[$_]));
		}
	}11..$#t; 
}
close IN;

map{
	print PED join("\t", $_, $_, 0, 0, 0, 0, @{$res{$_}}), "\n";
}keys %res;

print MAP join("\n", @pos), "\n";

close PED;
close MAP;
