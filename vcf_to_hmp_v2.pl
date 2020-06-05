#!/usr/bin/perl -w
use strict;

my $vcf_file = shift or die "perl $0 vcf_file\n";
my @arr;
my $IN;
if ($vcf_file=~/\.gz$/){
    open($IN, "zcat $vcf_file |") or die $!;
}
else{
    open($IN, $vcf_file) or die $!;
}
while(<$IN>){
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
    next if length $t[3]>1 or length $t[4]>1;
	my @gn;
	map{
	  if(/0[\|\/]0/){push @gn, $t[3].$t[3]}
	  elsif(/1[\|\/]1/){push @gn, $t[4].$t[4]}
	  elsif(/0[\|\/]1/){push @gn, $t[3].$t[4]}
	  else{push @gn, "NN"}
	}@t[9..$#t]; 
        #my $rs = $t[2]; 
        my $rs = join("_", @t[0,1]) ;
	print join("\t", ($rs, join("/", @t[3,4]), @t[0,1], "NA", "NA", "NA", "NA", "NA", "NA", "NA", @gn)), "\n";
}
close $IN;
