#!/usr/bin/perl -w
use strict;
use Getopt::Long;

my $sUsage = qq(Usage:
perl $0 
-in input sam or bam
-out  output_bam
-seed seed for the random function
-prop, 0-100
);

my (@input, $out, $seed, $prop);
GetOptions(
  '-in=s{1,}' => \@input,
  '-out=s'    => \$out,
  '-seed=i'   => \$seed,
  '-prop=i'   => \$prop
);

die $sUsage unless @input and $out;


$seed = time unless $seed;
srand($seed);

my $samtools = `which samtools`; 
chomp $samtools;

open (my $OUT, "|$samtools view -bS - >$out") or die $!;

foreach my $f (@input){
  my $fh;
  if($f =~ /sam$/i){open($fh, "$samtools view -Sh -F4 $f |") or die $!}
  elsif($f =~ /bam$/i){open($fh, "$samtools view -h -F4 $f |") or die $!}
  else{die "Error: File $f is not sam nor bam!!\n"}

  while(<$fh>){
       if(/^\@/){print $OUT $_; next}
       my $r = int(rand(100));
       print $OUT $_ if $r < $prop;
  }

  close $fh;
}
close $OUT;




