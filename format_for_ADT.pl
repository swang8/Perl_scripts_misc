#!/usr/bin/perl -w
use strict;
die qq(
perl $0 [input_file]\n
Input format:
>Excalibur_mira1_c13927:263
GGGCAGACAATAAATACACAGGCAGTCACACAAACATATCGATGTGTACA[A/G]AAATGAAGTTGCAGAAATAAGGCACTGCCTTGGATTAGAACACAGGTTGG
>RAC875_mira1_rep_c98289:16074
CAATGTTGGAGTTGTACTGTGAGAGGGCGCAGCTGCAAGATGGCCAAAGC[G/A]TTCTCGATGTTGGATGTGGATGGGGATCCCTCTCTGTATACATAGCAAAG
)unless @ARGV;
my $header = 'Locus_Name,Target_type,Sequence,Genome_Build_Version,Chromosome,Coordinate,Source,Source_Version,Sequence_Orientation,Plus_Minus';
my $id;
print $header, "\n";
while (<>)
{
  if (/>/) { $id=$1 if />(\S+)/; $id = $1 if />(\S+?:\d+):/; next}
  chomp;
  print join(",", ($id, "SNP", $_, 0,0,0,0,0, "Forward", "Plus")), "\n";
}
