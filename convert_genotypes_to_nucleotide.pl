#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
This script will convert genotype callings to nucleotides based on the genotyping design file.
Ref: http://www.illumina.com/documents/products/technotes/technote_topbot.pdf

Rules:
if SNP variation is A and [C or G], Allele_A is A and Allele_B is [C or G]; (the design will always be TOP)
if SNP variation is T and [C or G], Allele_A is T and Allele_B is [C or G]; (the design will always be BOT)
if SNP variation is A and T, then check the design; if TOP, then Allele_A is A and Allele_B is T; if BOT, then Allele_A is T and Allele_B is A;
if SNP variation is C and G, then check the design; if TOP, then Allele_A is C and Allele_B is G; if BOT, then Allele_A is G and Allele_B is C;

Usage:
perl $0
<genotyping assay design file>
<genotyping result file>
<covnerted file>
);

die $sUsage unless @ARGV == 3;

my ($design_file, $genotyping_file, $output_file) = @ARGV;
my %genotype_to_nucleotide = read_design_file($design_file);

open (IN, $genotyping_file) or die "can't open file $genotyping_file\n";
open (OUT, ">", $output_file) or die;
my $line_count = 0;
my %snp_index;
while (<IN>){
	next unless /\S/;
	$line_count++;
	chomp;
	my @data = split /\s+/, $_;
	if($line_count == 1){
		map{
			$snp_index{$_}=$data[$_] if exists $genotype_to_nucleotide{$data[$_]};
		}0..$#data;
		print OUT $_, "\n";
		next;		
	}
	
	map{
		next unless exists $genotype_to_nucleotide{$snp_index{$_}};
		$data[$_] = $genotype_to_nucleotide{$snp_index{$_}}{$data[$_]};
	} 0..$#data;
	
	print OUT join("\t", @data), "\n";
}
close IN;
close OUT;

sub read_design_file{
	my $file = shift;
	my %return;
	my $line_count = 0;
	my @nucleotides = qw(A T C G);
	my %int_nuc = map{$nucleotides[$_], $_}0..$#nucleotides;
	open (IN, $file) or die;
	while(<IN>){
		# "IWA13" "wsnp_BE399939D_Ta_2_1-0_B_F_1891210551"        "wsnp_BE399939D_Ta_2_1" "BOT"   "[T/C]" 29701384        "AATTCGCCGGAAAAAAAATGCAAGTCACAACCACATTCCAGCTTCTTTCA"
		next unless /\S/;
		$line_count++;
		next if $line_count == 1;
		s/\"//g;
		my @t = split /\s+/, $_;
		my ($id, $design, $var) = @t[2..4];
		$var =~ s/[^ATGV]//g;
		my @alleles = split //, $var;
		my $sum = sum(@int_nuc{@alleles});
		my ($aa_nuc, $bb_nuc);
		if($sum == 1){
			# [A/T]
			($aa_nuc, $bb_nuc) = ($design=~/TOP/i)?("A", "T"):("T", "A");			
		}
		elsif($sum == 5){
			# [C/G]
			($aa_nuc, $bb_nuc) = ($design=~/TOP/i)?("C", "G"):("C", "G");	
		}
		else{
			($aa_nuc, $bb_nuc) = sort{$a<=>$b} @alleles;
		}
		
		$return{$id}{"A"} = $aa_nuc;
		$return{$id}{"B"} = $aa_nuc;
		$return{$id}{"H"} = $var;		
	}
	close IN;
	return %return;
}

sub sum{
	my $return = 0;
	map{$return+=$_}@_;
	return $return;
}

