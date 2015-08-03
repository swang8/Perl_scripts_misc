#!/usr/bin/perl -w
use strict;
use Bio::SearchIO;

my $sUsage = qq(
suppose we took flanking sequence of SNPs and blat (blastn) against reference;
this scripts will parse the blast output and count the allele frequency for SNPs.

perl $0 <length of flanking seq> <blast_result_files>

);

die $sUsage unless @ARGV >= 2;

my ($flanking_lenght, @blat_files) = @ARGV;

my %allele_freq;

parse_blast_results(@blat_files);

foreach my $snp(keys %allele_freq)
{
	my @arr;
	foreach (keys %{$allele_freq{$snp}})
	{
		push @arr, $_."_".$allele_freq{$snp}{$_};
	}
	print join("\t", ($snp, @arr)), "\n";
}

# Subroutines
sub parse_blast_results
{
	my @files = @_;
	
	foreach my $file (@files){
		my $searchio = Bio::SearchIO->new(-format => 'blast', file => "$file" );
		while (my $result = $searchio->next_result())
		{
			last unless defined $result;
			my $query_name = $result->query_name;
			next unless $query_name =~/\S+/;
			$query_name =~ s/\s+$//;
			#print STDERR $query_name, "*\n";
			my ($ctg, $ctg_pos, $len) = split /:/, $query_name;
			my $snp_name = join(":", ($ctg, $ctg_pos));
			my $snp_pos = $ctg_pos>=$flanking_lenght?($flanking_lenght+1):$ctg_pos;
			while(my $hit = $result->next_hit())
			{
				next unless $hit->length >= 30;
				my $hsp = $hit->next_hsp;
				next if $hsp->evalue >1e-10;
				my $qry_start = $hsp->start("query");
				my $hit_seq = $hsp->hit_string;
                my $hit_strand = $hsp->strand('hit');
                print STDERR $hit_seq, "\n" if $hit_strand==-1;
				my $allele = uc(substr($hit_seq, ($snp_pos-$qry_start), 1));
				$allele_freq{$snp_name}{$allele} = 0 unless exists $allele_freq{$snp_name}{$allele};
				$allele_freq{$snp_name}{$allele}++
			}
			
		}		
	}


}


