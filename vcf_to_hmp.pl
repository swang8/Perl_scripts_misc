#!/usr/bin/perl -w
use strict;

my $hmp_file = shift or die "perl $0 vcf_file\n";
my @arr;
open(IN, $hmp_file) or die $!;
while(<IN>){
	chomp;
	my @t = split /\s+/, $_;
	if(/^\#CHROM/){
		#print '##fileformat=VCFv4.1', "\n";
		#print join("\t", "\#CHROM",  qw(POS     ID      REF     ALT     QUAL    FILTER  INFO    FORMAT) )
		#      ,"\t", join("\t", @t[11..$#t]), "\n";
               print join("\t", qw(rs      alleles chrom   pos     strand  assembly        center  protLSID        assayLSID       panelLSID       QCcode), @t[9..$#t]), "\n";
	       next;
	}
	next if /\#/;
	my @gn;
	map{
	  if(/0\|0/){push @gn, $t[3]}
	  elsif(/1\|1/){push @gn, $t[4]}
	  else{push @gn, "N"}
	}@t[9..$#t]; 

	print join("\t", ($t[2], join("/", @t[3,4]), @t[0,1], "NA", "NA", "NA", "NA", "NA", "NA", "NA", @gn)), "\n";
}
close IN;
