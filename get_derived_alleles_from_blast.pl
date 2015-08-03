#!/usr/bin/perl -w
use strict;
use Bio::SearchIO;

my $blast_output = shift or die;
parse_blast_results($blast_output);


sub parse_blast_results
{
	my $file = shift;
	my %return_hash;
	my $searchio = Bio::SearchIO->new(-format => 'blast', file => "$file" );
	while (my $result = $searchio->next_result())
	{
		last unless defined $result;
		my $query_name = $result->query_name;
		# wsnp_AJ612027A_Ta_2_1:60:A:G
		my ($snp, $snp_pos, $aa, $ab) = split /:/, $query_name;
		my $hit = $result->next_hit();
		next unless defined $hit;
		my $hsp = $hit->next_hsp();
		next unless defined $hsp;
		my $q_seq = $hsp->query_string;
		my @q_range = $hsp->range('query');
		my @arr = split //, $q_seq;
		my $new_pos;
		foreach (0..$#arr){
			if($arr[$_] eq '-'){$snp_pos++; next}
			$new_pos = $_ if ($q_range[0]+$_)==($snp_pos+1)
		}
		next unless defined $new_pos;
		my $h_seq = $hsp->hit_string;
		my $derive = substr($h_seq, $new_pos, 1);
		print $snp, "\t", $derive=~/$aa/i?$ab:$aa, "\n";
	}
	return %return_hash;
}