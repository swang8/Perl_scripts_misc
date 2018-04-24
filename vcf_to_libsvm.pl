#!perl -w
use strict;

my $vcf = shift or die "perl $0 <vcf>\n";

my @arr ;
open(IN, $vcf) or die $!;
my $line = 0;
my %results;
while(<IN>){
    chomp;
    my @t = split /\s+/,$_;
    if(/\#/){@arr = @t if /\#CHR/; next}
    $line++;
    map{
        my $v="";
        if($t[$_]=~/([01])\/([01])/){$v = $line . ":" . ($1+$2)}
        $results{$arr[$_]} = [] unless exists $results{$arr[$_]};
        push @{$results{$arr[$_]}}, $v if $v;
    }9..$#t;
}
close IN;

my $out = $vcf.".libsvm.txt";
open(OUT, ">$out") or die $!;
map{print OUT  join(" ", $_, @{$results{$_}}), "\n" if exists $results{$_}} @arr[9..$#arr];
