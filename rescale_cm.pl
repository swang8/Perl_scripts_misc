#!/usr/bin/perl -w
use strict;
# 1. covnert kosambi distance to recombination fraction: http://www.crypticlineage.net/lib/Kosambi.pdf
# 2. estimate the inflating factor using recombination fraction: http://www.hos.ufl.edu/sites/default/files/courses/pmb5056/2012_16_Linkage%20paper%20to%20post.pdf
# 3. get the corrected recombination fracton
# 4. convert recombination fraction to kosambi distance

## Shichen
#
sub kosambi_to_r {
  my $k = shift;
  $k = $k /100;
  my $r = 0.5 * (2.718**(4*$k)-1)/(2.718**(4*$k)+1);
  return $r
}

sub r_to_kosambi {
  my $r = shift;
  my $k = 0.25 * log((1 + 2*$r)/(1 - 2*$r)) * 100;
  return $k
}

sub calculate_inflating_factor {
  my ($r, $error) = @_;
  $error = 0.05 unless $error;
  return 1 if $r == 0;
  my $scale = 2*$error*(1-$error)*(1 - 2*$r)/$r;
  return $scale
}

while(<>){
  chomp;
  my @t = split /\s+/,$_;
 ##  1A  IWB345345  7.86 
  my $r = kosambi_to_r($t[-1]);
  my $inflating = calculate_inflating_factor($r, 0.05);
  my $r_corr = $r / (1+$inflating);
  my $k_corr = r_to_kosambi($r_corr);
  print join("\t", @t, $k_corr), "\n"
}
