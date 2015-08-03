#!/usr/bin/perl -w
use strict;

my $sUsage  = qq(

This script will extract genotype data from <genotype file> for each linkage group;

Usage: 
perl $0 
<linkage_groups_and_chromosome>
<MstMap output>
<genotype file>
);

die $sUsage unless @ARGV >= 3;
my ($lg_grp_chr, $mstmap_output, $genotype_file) = @ARGV;

my %lg_chromosome = read_linkage_group_chromosome_file($lg_grp_chr);

my %out_fh = get_file_handles(values %lg_chromosome);

my %id_chromsome = read_MstMap_output_file($mstmap_output, \%lg_chromosome);

output_genotype_files($genotype_file, \%id_chromsome, \%out_fh);


# subroutines
sub output_genotype_files
{
	my ($file, $id_chr_ref, $fh_ref) = @_;
	open (IN, $file) or die $!;
	while (<IN>){
		my $line = $_;
		if (/locus_name/){
			map {print {$_} $line} values %{$fh_ref};
			next;
		}
		next unless $line=~/\S/;
		my @t = split /\s+/, $line; 
		next unless exists $id_chr_ref->{$t[0]};
		#print $t[0], "\n";
		my $chr = $id_chr_ref->{$t[0]};
		my $fh = $fh_ref->{$chr};
		print {$fh} $_;		
	}
	close IN;
}


sub read_MstMap_output_file
{
	my $file = shift;
	open (IN, $file) or die $!;
	my %id_chr;
	my $linkage_grp = "";
	while (<IN>){
		next unless /\S/;
		next if /\;/;
		if (/group\s+(\S+)/){
			$linkage_grp = $1;
			print $linkage_grp, "\n";
			next;
		}
		my @t = split /\s+/, $_;
		next unless exists $lg_chromosome{$linkage_grp};
		print $t[0], "**\n";
		$id_chr{$t[0]} = $lg_chromosome{$linkage_grp};
	}
	close IN;	
	
	return %id_chr;
}


sub read_linkage_group_chromosome_file
{
	my $file = shift;
	open (IN, $file) or die $!;
	my %ld_chr;
	while (<IN>){
		chomp;
		next unless /\S/;
		my @t = split /\s+/, $_;
		map{$ld_chr{"lg" . $_} = $t[0]}@t[1..$#t];
	}
	close IN;
	
	return %ld_chr;	
}



sub get_file_handles
{
	my @accs = unique(@_);
	my %return_hash;
	foreach my $acc_id (@accs)
	{
		my $file = $acc_id . '.genotype';
		local *FH;
		open (FH, ">$file") or die "can't open file $file\n";
		$return_hash{$acc_id} = *FH{IO};
	}
	return %return_hash;
}

sub unique
{
	my %h = map {$_, 1}@_;
	return keys %h;
}