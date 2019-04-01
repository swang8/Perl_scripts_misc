#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
perl $0 <AB_nuc file> <genotyping in csv>

example: perl $0 /data3/Downloads/shichen/wheat_90K/90K_AB_to_Nucleotides.csv TAM1112_genomestudio_export.csv 3
);

die $sUsage unless @ARGV >= 2;

my ($ab_file, $geno_file, $index) = @ARGV;

$index = defined $index?($index-1):0;

my %ab_to_allele = read_ab_file($ab_file);

open(IN, $geno_file) or die $!;

while(<IN>){
    chomp; 
    next unless /\S/;
    my @t = split /\,/, $_;
    my $key = $t[$index];
    if(! exists $ab_to_allele{$key}){print $_, "\n"; next}
    map{$t[$_] = $ab_to_allele{$key}{$t[$_]} if exists $ab_to_allele{$key}{$t[$_]} }1..$#t;
    print join(",", @t), "\n"
}
close IN;

sub read_ab_file {
    my $f = shift;
    open(F, $f) or die $!;
    my %return;
    # BobWhite_c10173_317,TTTGTGATGCCATCAAAATATGGTCCAGACTTGCCTCAGGCAAAAGACCC[A/G]TCTGTGACTATCAAGGAGGTGCCCAGCAAAATTGTAGCGGTTGCGGCCTT,A/G,A,G
    while(<F>){
        chomp;
        my @t = split /,/, $_;
        $return{$t[0]}{"AA"} = $t[-2].$t[-2];
        $return{$t[0]}{"A"} = $t[-2].$t[-2];
        $return{$t[0]}{"AB"} = $t[-2].$t[-1];
        $return{$t[0]}{"H"} = $t[-2].$t[-1];
        $return{$t[0]}{"BB"} = $t[-1].$t[-1];
        $return{$t[0]}{"B"} = $t[-1].$t[-1];
    }
    close F;
    return %return;
}
