#!/usr/bin/perl -w
use strict;

my $f = shift;
my $IN;
if($f=~/gz$/){
  open($IN, "zcat $f |") or die $!;
}
else {
  open($IN, $f) or die $!;
}

my %count;
my $chr;
while(<$IN>){
  if (/>(\S+)/){$chr=$1; next}
  chomp;
  next unless /\S/;
  my $line = $_;
  map{my $base = substr($line, $_, 1); $count{$chr}{uc($base)}++ if $base=~/[atgc]/i} 0 .. (length $line) - 1; 
}
close $IN;

my %chr_sum;
my $total_sum;
foreach my $chr (keys %count) {
  foreach my $base(keys %{$count{$chr}}){
    $chr_sum{$chr} += $count{$chr}{$base};
    $total_sum +=  $count{$chr}{$base};
  }
}

foreach my $chr (sort{$a cmp $b}keys %count) {
  foreach my $base(sort{$a cmp $b}keys %{$count{$chr}}){
    print join("\t", $chr, $base, $count{$chr}{$base}, $count{$chr}{$base}/$chr_sum{$chr}), "\n";
  }
}

