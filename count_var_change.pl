#!/usr/bin/perl -w
use strict;
my $pattern = $ARGV[0];
#my @seq = qw(T G C A G);
my @seq  =split //, $pattern;

my $qcut = $ARGV[1];

my %h;
my $n = 0;
my $m = "";
my @read;
while(<STDIN>){
    $n++;
    if($n == 2 or $n == 4){
        #print STDERR $_, "\n";
        my @arr = split //, (substr($_, 0, scalar(@seq)));
        foreach my $ind (0..$#arr){
            $h{$ind}={} unless exists $h{$ind};
            if ($n == 2){
              @read = @arr;
              $m = $seq[$ind] . "->" . $read[$ind];
              print STDERR @arr, ": ", $m, "\n";
              $h{$ind}{$m} = 0 unless exists $h{$ind}{$m};
              $h{$ind}{$m}++;
            }
            else{
              my $score = ord($arr[$ind]) - 33;
              print STDERR join("\t", $ind, $m, $score), "\n";
              $m = $seq[$ind] . "->" . $read[$ind];

              if($score < $qcut){
                $h{$ind}{$m}--;
              }
            }
        }

    }
    $n=0 if $n==4;

}

foreach my $ind (0..$#seq){
    my @arr = sort{$h{$ind}{$b} <=> $h{$ind}{$a}}keys %{$h{$ind}};
    my $tot = 0;
    map{$tot += $h{$ind}{$_}}@arr;
    my @prop = map{sprintf("%.4f", $h{$ind}{$_}/$tot)}@arr;
    map{print join("\t", $qcut, $ind, $arr[$_], $h{$ind}{$arr[$_]}, $prop[$_]), "\n" }0..$#prop;
}

