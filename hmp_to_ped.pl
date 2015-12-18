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
	push @pos, join("\t", $t[2], $t[0], 0, $t[3]);	
	map{
		push @{$res{$arr[$_]}}, join(" ", @t[$_, $_]);	
	}11..$#t; 
}
close IN;

map{
	print PED join("\t", $_, $_, 0, 0, 0, 0, @{$res{$_}}), "\n";
}keys %res;

print MAP join("\n", @pos), "\n";

close PED;
close MAP;
