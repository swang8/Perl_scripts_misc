#!/usr/bin/perl 
use strict;

my ($file, $enz_seq, $flowcell, $lane) = @ARGV;
die qq(
perl $0 
<barcode_file> "Sample_name  barcode_sequence"
<enzyme_remaing> 
<flowcell_name> "XCXSDASDSA1212"
<lane_id>  1
) unless @ARGV ==4;
open (IN, $file) or die;
print join("\t", qw(Flowcell        Lane    Barcode Sample  PlateName       Row     Column)), "\n";

my $n = 0;
while(<IN>){
  chomp;
  $n++;
  my @t = split /\s+/,$_;
  $t[1] =~ s/$enz_seq$//i;
  print join("\t", $flowcell, $lane, $t[1], $t[0], "myPlate", "A", $n), "\n";
}
close IN;

