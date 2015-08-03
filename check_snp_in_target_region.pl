#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
perl $0
<gff3 file shows the cordinate of transcripts>
<vcf file>
);
die $sUsage unless @ARGV == 2;
my ($gff_file, $vcf_file) = @ARGV;

my %transcripts_vec = read_gff3($gff_file);

open (V, $vcf_file) or die;
while(<V>){
	next if /^\#/;
	my @t = split /\s+/, $_;
	my ($chr, $snp_pos) = @t[0, 1];
	print $_ if vec($transcripts_vec{$chr}, $snp_pos, 1) == 1;	
}
close V;

# Subroutine
sub read_gff3{
	my $file = shift or die;
	open (IN, $file) or die;
	my %return;
	while (<IN>){
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      31152   31418   .       +       .       ID=chain_1;Target=asmbl_1 1 267 +
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      82474   82524   .       +       .       ID=chain_2;Target=asmbl_2 1 51 +
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      82604   82667   .       +       .       ID=chain_2;Target=asmbl_2 52 115 +

		next unless /\S+/;
		my @t = split /\s+/, $_;
		my ($chr, $start, $end) = ($t[0], sort{$a<=>$b} @t[3,4]);
		$return{$chr} = '' unless defined $return{$chr};
		foreach ($start .. $end){
			vec($return{$chr}, $_, 1) = 0b1;
		}
	}
	close IN;
	
	return %return;
}