#!/usr/bin/perl -w
use strict;

die qq"
Usage:  perl $0 bam_file  chr1 chr2 ...\n
" unless @ARGV >= 2;

my $bam = shift;
my %chrs = map{$_, 1}@ARGV;

my $output = $bam;
$output =~ s/.bam//;
$output = $output . "_extracted_" . join("-", keys %chrs) . ".bam";


my $samtools = "samtools ";

open (IN, "$samtools view -h $bam |") or die $!;
open (OUT, "|$samtools view Sb - >$output") or die $!;

while(<IN>){
  if(/^\@/){print OUT $_; next}
  my @t = split /\s+/, $_; 
  print OUT $_ if exists $chrs{$t[2]}
}
close IN;
close OUT;
print "Extraction is done! The new file is ", $output, "\n";
