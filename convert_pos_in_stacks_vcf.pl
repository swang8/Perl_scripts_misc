#!/usr/bin/perl -w
use strict;
# convert the pos in the stacks vcf to pos in each tag (1-based);
my $sUsage = "perl $0 <vcf_file>  <read_length>\n";
die $sUsage unless @ARGV == 2;

my ($vcf, $read_len) = @ARGV;

open (V, $vcf) or die $!;
while(<V>){
  if(/^\#\#/){print $_; next}
  if(/^\#CHROM/){print "##Note: POS is 1-based\n"; print $_; next}
  chomp;
  my @t = split /\s+/,$_;
  $t[0] = "catalog_".$t[2];
  my $new_pos = $t[1] - ($t[2]-1) * $read_len - 1;
  if($new_pos > $read_len){print STDERR join("\t",$new_pos, @t[1,2]), "\n"}
  $t[1] = $new_pos;
  $t[2] = join(":", @t[0,1]);
  print join("\t", @t), "\n";
}
close V;
