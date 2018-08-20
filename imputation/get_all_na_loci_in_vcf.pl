#!/usr/bin/perl -w
use strict;
my $sUsage = "perl $0 <vcf> \n";
die $sUsage unless @ARGV >= 1;

my ($vcf, $prob) = @ARGV;

open(V, $vcf) or die $!;
while(<V>){
  if(/^\#/){ next}
  chomp;
  my @t = split /\s+/,$_;
  my @arr = ();
  foreach my $i (9..$#t){
    push @arr, $i if $t[$i]=~/\.\/\./;
  }
  print STDERR join("\t", @t), "\n";
  print join("\t", @t[0,1], @arr), "\n";
}
close V;
