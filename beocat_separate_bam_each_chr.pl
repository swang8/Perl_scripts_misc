#!/usr/bin/perl -w 
use strict;
use lib '/homes/wangsc/perl_lib';
use Parallel::ForkManager;
use File::Basename;

my @bams = @ARGV;
my $num_threads = 4;
#my $samtools_bin = "/homes/bioinfo/bioinfo_software/samtools/samtools ";
my $samtools_bin = "samtools ";

my $pm = new Parallel::ForkManager($num_threads);

foreach my $bam (@bams)
{
	$pm->start and next;
	open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
	my %out_fh = get_file_handles($bam);
	while(<IN>)
	{
		 if(/^\@/)
		 {
			 	foreach my $fh (values %out_fh)
			 	{
			 		print {$fh} $_;
			 	}			 	 
			 	next;
		 }
		chomp;
		my @data = split /\s+/, $_; 
		$data[4] = 100;
		my $chr = $1 if $data[2] =~ /^(\d)/;
		my $fh = $out_fh{$chr};
		print {$fh} join("\t", @data), "\n";
	}
	close IN;
	
	$pm->finish;
}

$pm->wait_all_children;

sub get_file_handles
{
	my $acc = shift;
	my @chrs = 1..7;
	my %return_hash;
	foreach my $chr (@chrs)
	{
		my $file = basename($acc, ".bam") . "_chr_" . $chr . ".bam";
		local *FH;
		open (FH, "|$samtools_bin view -Sb - > $file") or die "can't open file $file\n";
		$return_hash{$chr} = *FH{IO};
	}
	return %return_hash;
}