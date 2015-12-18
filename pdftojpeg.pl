#!/usr/bin/perl
use strict;
use File::Basename;

my @pdf_files = @ARGV;

map{
  my $out = basename($_, ".pdf");
  my $cmd = "pdftocairo -jpeg $_ $out";
  print $cmd, "\n";
  die "$cmd failed!!\n" if system($cmd);
}@pdf_files;
