#!/usr/bin/perl -w
use strict;
my $sUsage = "perl $0  <sam/bam>  <bed>\n";
die $sUsage unless @ARGV == 2;

my ($bam, $bed) = @ARGV;

my %regions = read_bed($bed);
my $output = $bam . "_extracted.bam";

my $samtools = "samtools";

open(IN, "$samtools view -h $bam |") or die $!;
open (OUT, "|$samtools view -Sb - >$output") or die $!;

while(<IN>){
  if(/^@/){print OUT $_; next}
  my @t = split /\s+/,$_; 
  # HWI-ST1410:168:C6B7RACXX:4:1101:1913:1921       99      chr5B_part2     245745298       40      101M
  my $chr = $t[2];
  my $start = $t[3];
  my $len = length $t[9]; 
  my $end = $start + $len - 1;
  next unless exists $regions{$chr};
  print OUT $_ if (check_region(\%regions, $chr, $start, $end));
}
close OUT;
close IN;

##
sub read_bed{
  my $f = shift;
  open(F, $f) or die $!;
  my %return;
  while(<F>){
    chomp;
    my @t = split /\s+/,$_;
    push @{$return{$t[0]}}, [@t[1,2]];
  }
  close F;
  map{my $k = $_; $return{$k} = [sort {$a->[0] <=> $b->[0]} @{$return{$k}}] }keys %return;
  return %return
}

sub check_region {
  my ($reg, $chr, $s, $e) = @_;
  if(exists $reg->{$chr}) {
     my $index = overlap_search($reg->{$chr}, $s, $e);
     print STDERR $index, "\n" if $ENV{DEBUG};
     if($index != -1){return 1}else{return 0}
  }
  return 0;
}

sub overlap_search {
  my ($arrref, $s, $e) = @_;
  my $i = 0; 
  my $j = scalar @{$arrref} - 1;
  while ($j >= $i) {
    my $m = int(($i + $j) / 2);
    if ( ($arrref->[$m][0] >= $s and $arrref->[$m][0] <= $e) or ($s >= $arrref->[$m][0] and $s <= $arrref->[$m][1]) )  {return $m}
    if ( $s > $arrref->[$m][1]) {$i = $m + 1}
    if ($arrref->[$m][0] > $e) {$j = $m - 1}
  }
  return -1;
}
