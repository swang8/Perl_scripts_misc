#!/usr/bin/perl -w
use strict;

my ($f1, $f2) = @ARGV;
die "perl $0 <sampled_5000_reads_R1.blastn.out.parsed>  <sampled_5000_reads_R2.blastn.out.parsed> \n!" unless @ARGV == 2;

my %aln_r1 = get_aln($f1);
my %aln_r2 = get_aln($f2);

foreach my $k(keys %aln_r1) {
  next unless exists $aln_r2{$k};
  next unless $aln_r1{$k}->[0] eq $aln_r2{$k}->[0];
  my @arr = (split("-", $aln_r1{$k}->[1]), split ("-", $aln_r2{$k}->[1]));
  @arr = sort {$a <=> $b} @arr;
  my $len = $arr[-1] - $arr[0];
  print join("\t", $aln_r1{$k}->[2],   $aln_r1{$k}->[1], $aln_r2{$k}->[1], $len), "\n";
}

##
sub get_aln {
  my $f = shift or die $!;
  my %return;
  open(IN, $f) or die $!;
  while(<IN>){
    chomp; 
    next unless /\S/;
    my @t = split /\t/,$_;
    $t[0]=~s/\/[12]$//;
    next if exists $return{$t[0]};
    my($query_len, $query_range) = @t[4, 6]; my @query = split /-/, $query_range;
    my @p = split /-/, $t[-2];  my $strand = $p[0] < $p[1]?1:-1;
    $p[0] = $p[0] - $strand * ($query[0] - 1);
    $p[1] = $p[1] + $strand * ($query_len - $query[0]);
    $return{$t[0]} = [$t[1], join("-", @p), $t[2]];
  }
  return %return;
}
