#!/usr/bin/perl -w
use strict;
use Cwd;
use File::Basename;

my $folder = shift;
my $pop_file = shift;
my %pop = get_pop($pop_file) if $pop_file;
my $abs_folder = Cwd::abs_path($folder);
my $output_dir = "./renamed";
mkdir($output_dir) unless -d $output_dir;

my @files = <$abs_folder/*gz>;

foreach my $f (@files) {
    next unless $f =~ /_R[12]_/;
    next if $f =~ /Undertermin/;
    my $name = basename($f);
    my $acc = $1 if $name =~ /^(\S+)_S\d+_L00\d/;
    my $fr = $f=~/_R1_/?"F":"R";
    my $p = exists $pop{$acc}?$pop{$acc}:"pop1";
    my $rename = $p . "_" . $acc . "." . $fr. ".fq.gz";
    $rename = $output_dir . "/" . $rename;
    system("ln -s $f  $rename");
}

# subroutine
sub get_pop {
    my $f = shift;
    open (IN, $f) or die $!;
    my %return;
    while(<IN>){
        chomp;
        my @t = split /\s+/,$_;
        $return{$t[0]} = $t[1]
    }
    close IN;
    return %return;
}
