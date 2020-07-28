#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;

die "perl $0 <SNP position file,vcf > <contig fasta> <flanking length> <output file>\n" unless @ARGV >= 3;
## SNP postion file format

my ($snp_file, $ctg_fasta_file, $flank_len, $oligo_file) = @ARGV;
open (OL, ">$oligo_file") or die $!;
my $ctg_fasta = Bio::DB::Fasta->new($ctg_fasta_file);
my %snp_pos = read_snp_file($snp_file);

foreach my $id (keys %snp_pos)
{
	my $obj = $ctg_fasta->get_Seq_by_id($id);
    next unless defined $obj;
	my $length = $obj->length;
	foreach my $arrref (@{$snp_pos{$id}})
	{
        my ($pos, $str) = @$arrref;
		my $start = $pos>$flank_len?$pos-$flank_len:0;		
		my $end = ($length - $pos)>=$flank_len?$pos+$flank_len:$length;
        next if $start > $end;
        #print STDERR $pos, "\t", $start, "\t", $end, "\n";
		my $subseq = $obj->subseq($start => $end);
        my $snp_pos = $pos>$flank_len?$flank_len:($pos-1);
        substr($subseq, $snp_pos,1) = $str;
		print OL ">", join(":", ($id, $pos, $length)),"\n", $subseq,"\n";
		
	}
}

sub read_snp_file
{
	my $file = shift;
	my %return;
	open (IN, $file) or die $!;
	while(<IN>)
	{
		chomp; 
		next if /^\s+$/;
		next if /^\#/;
		s/^>//;
		my @t=split /\s+/,$_;
		push @{$return{$t[0]}}, [$t[1], "[".join("/", @t[3,4])."]" ];
	}
	close IN;
	return %return;
}
