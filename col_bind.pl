#!/usr/bin/perl -w
use strict;

my @files = @ARGV;

my @res;

foreach my $ind ( 0 .. $#files){
  my $f = $files[$ind];
  open(IN, $f) or die $!;
  while(<IN>){
    chomp;
    push @{$res[$ind]}, $_;
  }
  close IN;
}

my $max_len = 0;

map{
  my $len = scalar @{$_};
  $max_len = $len if $len > $max_len; 
}@res;

foreach my $ind (0 .. $max_len-1){
  my @p = ();
  map{push @p, $_->[$ind]}@res;
  print join("\t", @p), "\n"; 
}






