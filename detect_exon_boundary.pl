#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
# CS genomic sequences were mapped to transcript assemblies
# This script will detect potential exon boundaries in the transcript assemblies.

Usage: 
perl $0
<blat result file>
<output file>
<minimum similarity, 95>
<minimum leghtn of fragment, 30>
);
die $sUsage unless @ARGV >= 2;
my ($blat_file, $out_file, $min_sim, $min_len) = @ARGV;
$min_sim = 95 unless defined $min_sim;
$min_len = 30 unless defined $min_len;

my %exon_boundary = read_blat_file($blat_file, $min_sim, $min_len);

open (OUT, ">$out_file") or die $!;
foreach my $id(keys %exon_boundary)
{
	print OUT $id;
	foreach (@{$exon_boundary{$id}})
	{
		print OUT "\t", join("_", @$_)
	}
	print OUT "\n";	
}
close OUT;


# Subroutines

sub read_blat_file
{
	my($file, $min_sim, $min_len) = @_;
	open (IN, "$file") or die $file;
	my $vec_bit_width = 8;
	my %ctg_vec; my %ctg_vec_max;
	while(<IN>)
	{
		chomp;
		next unless /^\S+/;
		my @data = split /\t/, $_;
		my ($similarity, $length, $num_gap) = @data[2, 3, 5];
		next unless $similarity >= $min_sim and $length >= $min_len and $num_gap == 0;
		my ($ctg_name, $start, $end) = @data[1, 8, 9];
		next unless $ctg_name eq 'BobWhite_mira1_c41896'; # for test
		print STDERR '$ctg_name: ', $ctg_name, "\n";
		($start, $end) = ($end, $start) if $start > $end;
		$ctg_vec_max{$ctg_name} = $end unless exists $ctg_vec_max{$ctg_name};
		$ctg_vec_max{$ctg_name} = $end if $end > $ctg_vec_max{$ctg_name};
		
		$ctg_vec{$ctg_name} = '' unless exists $ctg_vec{$ctg_name};
		foreach ($start..$end)
		{			
			if(vec($ctg_vec{$ctg_name}, $_, $vec_bit_width) == 0b1)
			{
				vec($ctg_vec{$ctg_name}, $_, $vec_bit_width) += 0b1 unless vec($ctg_vec{$ctg_name}, $_, $vec_bit_width) == 256;
			}
			else
			{
				vec($ctg_vec{$ctg_name}, $_, $vec_bit_width) = 0b1
			}		
		}
	}
	close IN;
	my %return;
	foreach my $id (keys %ctg_vec)
	{
		my $max = $ctg_vec_max{$id};
		my $vec = $ctg_vec{$id};
		my @boundary = calculate_exon_boundary($vec, $max);
		$return{$id} = [@boundary];
	}
	
	return %return;
}

sub calculate_exon_boundary
{
	my ($vec, $max) = @_;
	my @boundaries;
	my $vec_bit_width = 8;
	my $previous_status;
	my $previous_position;
	my ($current_status, $current_position);
	foreach my $index (1..$max)
	{
		if($index == 1){$previous_status = vec($vec, $index, $vec_bit_width); $previous_position = $index; next}
		my ($current_status, $current_position) = (vec($vec, $index, $vec_bit_width), $index);
		next if $current_status == $previous_status;
		push @boundaries, [$previous_position, $current_position-1, $previous_status];
		print STDERR join("\t", ($previous_position, $current_position-1, $previous_status)),"\n";
		$previous_position = $current_position;
		$previous_status = $current_status;
	}
	push @boundaries, [$previous_position, $max, $current_status];
	return @boundaries;
}

