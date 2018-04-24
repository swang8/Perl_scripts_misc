#!perl -w
use strict;

my $sUsage = "perl $0 <key_file> <lane_id> <fastq_files>\n";
die $sUsage unless @ARGV >= 3
my ($key_file, $lane, @fq_files) = @ARGV;

my %keys = read_key_file($key_file)
