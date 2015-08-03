#!/usr/bin/perl -w 
use strict;

my $sUsage = qq(
perl $0
</home/swang/90K_assay_design/final/blat_suvey_sequence/90K_SNP_mapped_chromosomes.out>
<synop_linkgrp_chr_summary_checked>
<mstmap_input_file>
<mstmap_output_file>
);

die $sUsage unless @ARGV == 4;
my ($snp_mapped_chr_file, $linkgrp_summary_file, $mstmap_input_file, $mstmap_output_file) = @ARGV;
my @chrs = map{$_."A", $_."B", $_."D"}1..7;

my %snp_chr = read_snp_mapped_chr_file($snp_mapped_chr_file);
my %linkgrp_chr = read_linkgrp_summary_file($linkgrp_summary_file);
my %snp_linkgrp = read_mstmap_output($mstmap_output_file);
my ($header, $genotype_ref) = read_mstmap_input($mstmap_input_file);

# output
foreach my  $chr (@chrs){
	my $output = $mstmap_input_file . "_chr_" . $chr;

	my @snps_belong_to_chr = ();
	my %extracted;
	foreach my $c (keys %snp_linkgrp){
		my $grp = $snp_linkgrp{$c};
		next unless exists $linkgrp_chr{$grp} ;
		if ($linkgrp_chr{$grp} eq $chr){
			push @snps_belong_to_chr, $c;
			$extracted{$c} = 1;
		}		
	}
	
	foreach my $c (keys %snp_chr){
		next if exists $extracted{$c};
		next if exists $snp_linkgrp{$c};
		push @snps_belong_to_chr, $c if $snp_chr{$c} eq $chr and exists $genotype_ref->{$c};
	}
	
	open (OUT, ">$output") or die $!;
	my $num_loci = scalar @snps_belong_to_chr;
	$header =~ s/cut_off_p_value\s\S+/cut_off_p_value 1/;
	$header =~ s/number_of_loci \d+/number_of_loci $num_loci/;
	print STDERR "$chr\t$num_loci\t$1\n" if $header =~ /(number_of_loci \d+)/;
	print OUT $header, "\n";
	
	my %snps = map{$_, 1}@snps_belong_to_chr;
	foreach my $c (keys %$genotype_ref){
		print OUT $genotype_ref->{$c}, "\n" if exists $snps{$c};
	}
	close OUT;
}


# Subroutines
sub read_snp_mapped_chr_file
{
	my $file = shift or die;
	my %return;
	open (IN, $file) or die $!;
	while (<IN>){
		chomp;
		my @t = split /\s+/, $_; 
		$return{$t[0]} = $t[1];
	}
	close IN;
	return %return;
}

sub read_linkgrp_summary_file
{
	my $file = shift or die;
	my %return;
	open (IN, $file) or die $!;
	while (<IN>){
		chomp;
		my @t = split /\s+/, $_; 
		$return{$t[0]} = $t[-1];
	}
	close IN;
	return %return;	
}

sub read_mstmap_output
{
	my $file = shift or die;
	my %return;
	open (IN, $file) or die $!;
	my $group;
	while (<IN>){
		chomp;
		next if /\;/;
		next unless /\S/;
		if (/group (\S+)/){$group = $1; next}
		if(/^(\S+)/){$return{$1} = $group}
	}
	close IN;
	return %return;	
}

sub read_mstmap_input
{
	my $file = shift or die;
	my(@header, %genotype);
	open (IN, $file) or die $!;
	my $flag = 0;
	while(<IN>){
		if($flag==0){
			chomp;
			push @header, $_;
			if (/locus_name/){$flag=1}
		}
		else{
			chomp;
			my $marker = $1 if /^(\S+)/;
			$genotype{$marker} = $_;
		}
	}
	close IN;
	
	return (join("\n", @header), \%genotype);
}

