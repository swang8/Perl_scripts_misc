#!/usr/bin/perl -w
use strict;
my $sUsage = qq"
perl $0 
<fastq files> 
<number of bases to be trimmed, +4 means trim 4 bases from left end, -4 means trim 4 bases from right end>\n";

print $sUsage unless @ARGV;
my $num_base = pop @ARGV;
my @files = @ARGV;
foreach my $file (@files)
{
  open (IN, "$file") or die $!;
  my $out = $file . '_trim_'. $num_base;
  open (OUT, ">$out") or die $!;
  while (<IN>)
  {
    if (/^@/ or /^\+/){print OUT $_; next}
    chomp;
    my $len = length $_;
    if ($num_base < 0)
    {
      print OUT substr ($_, abs($num_base)),"\n";
    }
    else {print OUT substr($_, 0, ($len+$num_base)),"\n"}
  }
  close IN;
  close OUT;
}


