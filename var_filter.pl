#!/usr/bin/perl -w
use strict;

my $remove_criteria = qq(
For SNPs:
QD < 2.0
MQ < 40.0
FS > 60.0
SOR > 3.0
MQRankSum < -12.5
ReadPosRankSum < -8.0

For indels:
QD < 2.0
ReadPosRankSum < -20.0
InbreedingCoeff < -0.8
FS > 200.0
SOR > 10.0
);

my %filter_SNP = (
QD => [20, '<'], 
MQ => [40, '<'],
FS => [60, '>'],
SOR => [3, '>'],
MQRankSum => [-12.5, '<'],
ReadPosRankSum => [-8, '<']
);

my %filter_Indel = (
QD => [2, '<'],
ReadPosRankSum => [-20, '<'],
InbreedingCoeff => [-0.8, '<'],
FS => [200, '>'],
SOR => [10, '>']
);

while(<>){
    if (/^\#/){print $_; next}
    my @t = split /\s+/,$_;
    my %p = map{split /=/, $_}(split /;/, $t[7]);
    my $score = 0;
    my $isSNP = length $t[3] == 1 and length $t[4] ==1 ? 1:0;
    my %type = $isSNP?%filter_SNP:%filter_Indel;
    foreach my $s (keys %type){
        if(exists $p{$s}){
            my $e = eval($p{$s} . $type{$s}[1] . $type{$s}[0]);
            #print STDERR $p{$s} . $type{$s}[1] . $type{$s}[0], "\t", $e, "\n";
            $score += $e;
        }    
    }
    $t[6] = $score>0?"FAIL":"PASS";
    print join("\t", @t), "\n"
}
