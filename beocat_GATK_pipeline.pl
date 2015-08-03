#!/usr/bin/perl -w
use strict;
use lib '/homes/wangsc/perl_lib'; # for beocat;
use Parallel::ForkManager;
use File::Basename;

my $sUsage = qq(

Suppose we have bam files for each accessions seperately (sample1.bam, sample2.bam, ...), call variations using GATK based on these bam files.
Steps:
1. sort each bam file (samtools sort) + index the bam file (samtools index)
2. realignment (GATK, -T RealignerTargetCreator)
3. MarkDuplicates for realign bam file (picard, MarkDuplicates.jar) + index the bam file (samtools index)
4. Base recalibration (GATK, -T CountCovariates) + index for recalibrated bam file (samtools index)
5. Calling variations (GATK, -T UnifiedGenotyper or HaplotypeCaller)
6. Variation quality score recalibration (optional)

Usage:
perl $0
<reference fasta file>
<output prefix for variation file>
<bam files>

example:
perl $0 ref.fasta test sample_*.bam
);

die $sUsage unless @ARGV;
my ($ref_fasta, $out_prefix, @bam_files) = @ARGV;

# predefined 
#my $samtools_bin = "/homes/wangsc/Tools/samtools ";
my $samtools_bin = "samtools ";
my $picard_dir  = "/homes/wangsc/Tools/picard";
my $GATK_jar = "/homes/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $MAX_THREADS = 16;

# sort bam files
my @sorted_bams;
my @sort_cmds;
foreach my $bam (@bam_files)
{
	my $sorted_prefix = basename($bam, ".bam") . "_sorted";
	push @sorted_bams , $sorted_prefix . ".bam";
	my $cmd = $samtools_bin . "sort $bam $sorted_prefix";
	push @sort_cmds, $cmd;
}

run_parallel_jobs(\@sort_cmds, $MAX_THREADS);


sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}





			