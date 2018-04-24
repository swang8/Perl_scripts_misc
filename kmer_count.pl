#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;

unless (@ARGV == 2){
    print "perl $0 <fasta_file> <K>\n";    
    exit();
}

my ($f, $k) = @ARGV;

my $gn = Bio::DB::Fasta->new($f);
my @ids  = $gn->get_all_primary_ids;

my %count;
foreach my $id (@ids){
    my $seq = $gn->get_Seq_by_id($id);
    my $len = $seq->length;
    for (my $i = 0; $i <= $len - $k; $i++){
        my $kmer = $seq->subseq($i => $i + $k - 1);
        $kmer = uc($kmer);
        next if $kmer =~ /^[ATGC]/;
        $count{$kmer} ++; 
    }
}

map{print $_, "\t", $count{$_}, "\n"}sort{$count{$b} <=> $count{$a}}keys %count;
