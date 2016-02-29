#!/usr/bin/perl -w
use strict;

my @arr;
while(<>){
  chomp;
  my @t = split /\s+/,$_;
  ## snp1  0.2
  ## snp2  0.6
  next unless @t == 2;
  push @arr, [@t];
}

@arr = sort {$a->[1] <=> $b->[1]}@arr; 

my @pos;
push @pos, $arr[-1][1];
foreach my $ind (1 .. $#arr){
  my $p = $pos[$ind-1] + ($arr[$ind-1][1] - $arr[$ind][1]);
  push @pos, $p;
}

map{
  print $arr[$_][0], "\t", $pos[$_], "\n" 
}0..$#arr; 
