#!/usr/bin/perl -w
use strict;
my $file = shift or die;
open (IN, $file) or die;
while (<IN>){
  if(/>/){print $_; next}
  chomp; 
  my $line = $_;
  my $length = length($line);
  my $index = 0;
  foreach (0..($length - 1)){
	my $char = substr($line, $_, 1);
	if($char eq 'X'){print "E"}
	else{print $char}
  }
  print "\n";
}
close IN;
