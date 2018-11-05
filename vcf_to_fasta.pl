#!/usr/bin/perl -w
use strict;
my $vcf = shift or die "Usage:\n\tperl $0 <vcf>\n";

open(IN, $vcf) or die $!;
my %fasta;
my @arr;
while(<IN>){
  chomp;
  my @t = split /\s+/,$_;
  if(/^\#CHROM/){@arr=@t; next}
  next if /\#/;
  my $len = length $t[3]; $len = length $t[4] if (length $t[4]) > $len;
  my $missing;
  map{$t[3] .= "-"; $t[4] .= "-"; $missing .= "-"}1..$len; $t[3] = substr($t[3], 0, $len); $t[4] = substr($t[4], 0, $len); 
  map{
    if($t[$_] =~ /0\/0/){$fasta{$_} .= $t[3]}
    elsif($t[$_] =~ /1\/1/){$fasta{$_} .= $t[4]}
    elsif($t[$_] =~ /0\/1:(\d+)\,(\d+)/){ if($1>$2){$fasta{$_} .= $t[3]}else{$fasta{$_} .= $t[4]} }
    else{$fasta{$_} .= $t[3]} # use ref for missing data 
  }9..$#t;
}
close IN;

foreach (keys %fasta){
  print ">", $arr[$_], "\n", $fasta{$_}, "\n"
}

