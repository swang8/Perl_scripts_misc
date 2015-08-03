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
	my @arr = (0,0,0);
	foreach my $type(keys %{$transcripts_vec{$chr}})
	{
		my $val = vec($transcripts_vec{$chr}{$type}, $snp_pos, 1);
		my $flag = $val==1?1:0;
		if($type eq 'transcript'){$arr[0] = $flag}
		elsif($type eq 'exon'){$arr[1] = $flag}
		elsif($type eq 'CDS'){$arr[2] = $flag}
	}
	print join("\t", (@t[0,1], @arr)), "\n";	
}
close V;

# Subroutine
sub read_gff3{
	my $file = shift or die;
	open (IN, $file) or die;
	my %return;
	while (<IN>){
#1000404_1al     mips    transcript      1869    2049    .       -       .       gene_id "Ta1alLoc000002"; transcript_id "Ta1alLoc000002.1"; class="USL_1";;
#1000404_1al     mips    exon    1869    2049    .       -       .       gene_id "Ta1alLoc000002"; transcript_id "Ta1alLoc000002.1"; exon_number "1";
#1000404_1al     mips    CDS     1954    2049    .       -       .       gene_id "Ta1alLoc000002"; transcript_id "Ta1alLoc000002.1"; coding_exon_number "1";


		next unless /\S+/;
		my @t = split /\s+/, $_;
		my ($chr, $type, $start, $end) = ($t[0], $t[2], sort{$a<=>$b} @t[3,4]);
		$return{$chr}{$type} = '' unless defined $return{$chr}{$type};
		foreach ($start .. $end){
			vec($return{$chr}{$type}, $_, 1) = 0b1;
		}
	}
	close IN;
	
	return %return;
}