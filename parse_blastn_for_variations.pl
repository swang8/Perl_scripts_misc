#!/usr/bin/perl -w
use strict;
use Bio::SearchIO;

die "perl $0 <blast_file>\n" unless @ARGV;

parse_blastx_results(shift);

sub parse_blastx_results
{
	my $file = shift;
	my %return_hash;
	my $searchio = Bio::SearchIO->new(-format => 'blast', file => "$file" );
	print "Contigs(Chrs)\tctg_Position\tref_Position\tRef_allele\tAlt_allele\n";
	while (my $result = $searchio->next_result())
	{
		last unless defined $result;
		my $query_name = $result->query_name;
		while(my $hit = $result->next_hit())
		{
            my $hsp = $hit->next_hsp(); next unless defined $hsp;
			my $query_str = $hsp->query_string;
			my $hit_str = $hsp->hit_string;
			
			my $hit_strand = $hsp->strand("hit");
			my $hit_start = ($hit_strand == -1)?$hsp->end("hit"):$hsp->start('hit');
			
			#if($hit_strand == -1){print STDERR $hsp->start("hit"), "\t", $hsp->end("hit"), "\n";}
			
			foreach my $pos (1..(length $query_str))
			{
				my $query_char = uc(substr($query_str, $pos-1, 1));
				my $hit_char = uc(substr($hit_str, $pos-1, 1));
				if($query_char ne $hit_char){
					print $hit->name, "\t", $hit_start + $hit_strand*($pos-1), "\t", $hsp->start("query") + $pos - 1, "\t", $hit_char, "\t", $query_char, "\n";
				}
			}
			 
		}
	}
}
# SW 09.11.2013
