#!/usr/bin/perl -w
use strict;

my $sUsage = "perl $0 <input_VCF> <output>\n";
die $sUsage unless @ARGV == 2;

my ($input, $output) = @ARGV;
open(IN, $input) or die $!;
open (OUT, ">$output") or die $!;

while (<IN>){
  if(/\#/){print OUT $_; next}
  my $ref = () = /0\/0/g;
  my $alt = () = /1\/1/g;
  my $het = () = /0\/1/g;
  next if $alt + $ref == 0;
  chomp;
  my @t = split /\s+/, $_;
  my $het_rate = $het/ ($ref+$alt+$het);
  my $ref_rate = $ref/($ref+$alt);
  my $alt_rate = $alt/($ref+$alt);
  if ($ref > $alt and $alt_rate < 0.05){
      # het to alt homo
      map{$t[$_]=~s/0\/1/1\/1/g}9..$#t;; 
      $t[6]  = "hetToAlt";
      print STDERR join("\t", @t[0,1], $ref, $alt, $het, "hetToAlt"), "\n";
  }
  elsif ($alt > $ref and $ref_rate < 0.05){
      # het to ref
      map{$t[$_]=~s/0\/1/0\/0/g}9..$#t;; 
      $t[6]  = "hetToRef";
      print STDERR join("\t", @t[0,1], $ref, $alt, $het, "hetToRef"), "\n"
  }
  else{
      print STDERR join("\t", @t[0,1], $ref, $alt, $het, "hetNoChange"), "\n";
  }
  print OUT join("\t", @t), "\n";
}
close IN;
close OUT;
