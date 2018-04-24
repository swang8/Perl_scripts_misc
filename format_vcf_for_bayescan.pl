#!perl -w
use strict;

my $sUsage = "perl $0 <vcf> <sample.csv>\n";

die $sUsage unless @ARGV == 2;

my ($vcf, $sample) = @ARGV;

open(CSV, $sample) or die $!;
my %h; 
my %g;
while(<CSV>){
  chomp;
  my @t = split /,/, $_;
  $h{$t[0]} = $t[1];
  $g{$t[1]} = 0 unless exists $g{$t[1]};
  $g{$t[1]}++
}
close CSV;

open(VCF, $vcf) or die $!;
my %geno;
my @arr;
my @index;
while(<VCF>){
  chomp;
  my @t = split /\s+/,$_;
  if(/\#/){
      next unless /^\#CHR/;
      @arr=@t;
      map{push @index, $_ if exists $h{$t[$_]}}9..$#t;
      next
  } 
  map{
    my $s = $t[$_];
    my $g = "";
    if($s=~/\.\/\./){$g=1}
    else{
       my @p = ($1, $2) if $s=~/^(\d)\/(\d)/;
       $g = $p[0] + $p[1]
    }
    push @{$geno{$arr[$_]}}, $g;    
  }@index;
}
close VCF;

# # output sample numeric
# my @samples = keys %h;
# my %sample_numeirc = map{$sample[$_], $_+1}0..$#samples;
# open(OUT, ">sample.numeirc.txt") or die $!;
# map{print OUT $samples[$_], "\t", $_+1, "\n"}0..$#samples;
# close OUT;

# output populaiton numeric ids
my @pops = keys %g;
my %pop_numeric = map{$pops[$_], $_+1}0..$#pops;
open(OUT, ">pop.numeirc.txt") or die $!;
map{print OUT $pops[$_], "\t", $_+1, "\n"}0..$#pops;
close OUT;

# output snp genotype file
open(OUT, ">snp_geno_for_bayescan.txt") or die $!;
foreach  my $p (sort{$pop_numeric{$a} <=> $pop_numeric{$b}} keys %pop_numeric){
   my @inds = grep{$h{$_} eq $p}keys %h;
   map{
       print OUT join("\t", $_+1, $pop_numeric{$h{$inds[$_]}}, @{$geno{$inds[$_]}}), "\n";
   }0..$#inds;
}
close OUT;

