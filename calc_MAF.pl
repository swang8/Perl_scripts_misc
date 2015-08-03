#!/usr/bin/perl -w
use strict;

my $count = 0;
my @snp_index;
my @first;
my %h;
while(<>)
{
  my @data = split /\s+/, $_;
  $count++;
  if($count == 1){
    @first = @data;
    map{push @snp_index, $_ if $data[$_]=~/wsnp/}0..$#data;
    next; 
  }
  foreach my $ind (@snp_index){
    my $snp = $first[$ind];
    my $genotype = $data[$ind];
    #print $genotype, "\n";
    next if $genotype=~/NA/;
    $h{$snp}{$genotype}++;
  }
}

foreach my $snp (keys %h){
  my @vals = values %{$h{$snp}};
  if(@vals == 1){
    print join("\t", ($snp, 0, @vals, 0), "\n");
  }
  else{
    @vals = sort {$a <=> $b} @vals;
    @vals = @vals[-2, -1];
    print join("\t", ($snp, @vals, $vals[0]/($vals[0]+$vals[1]))), "\n";
  }
}
