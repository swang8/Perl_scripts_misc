#!/usr/bin/perl -w
use strict;
my $sUsage = "perl $0 <vcf> <probability, 0.1>\n";
die $sUsage unless @ARGV >= 2;

my ($vcf, $prob) = @ARGV;

open(V, $vcf) or die $!;
while(<V>){
  if(/^\#/){print $_; next}
  chomp;
  my @t = split /\s+/,$_;
  my @arr = ();
  foreach my $i (9..$#t){
    next if $t[$i]=~/\.\/\./;
    my $r = rand(1);
    if ($r < $prob){
      push @arr, $i;
      $t[$i] = './.';
    }
  }
  print join("\t", @t), "\n";
  print STDERR join("\t", @t[0,1], @arr), "\n";
}
close V;
