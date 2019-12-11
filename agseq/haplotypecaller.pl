#!/usr/bin/perl -w
use strict;
#use lib '/homes/wangsc/perl_lib'; # for beocat;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;
use File::Basename;
use Getopt::Long;

my $sUsage = qq(
###########################################################################################################################
	Suppose we have bam files for each accessions separately (sample1.bam, sample2.bam, ...), 
	call variations using GATK based on these bam files.
	Steps:
	1. sort each bam file (samtools sort) + index the bam file (samtools index)
	2. realignment (GATK, -T RealignerTargetCreator + -T IndelRealigner)
	3. MarkDuplicates for realign bam file (picard, MarkDuplicates.jar) + index the bam file (samtools index)
	4. Base quality recalibration (GATK, -T CountCovariates) + index for recalibrated bam file (samtools index)
	5. Calling variations (GATK, -T HaplotypeCaller)
	
	Usage:	
	perl $0
	-ref                reference fasta file
	-out_prefix         output prefix for variation file
	-region             specific region for variation calling, chr_1:12345-876812
	-dcov               mean coverage, default: 200
	-bam                processed bam files: 1.bam 2.bam 3.bam
	-gatk		    The path to the gatk jar, i.e.,  /home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar
        -params		    Other parameters for GATK, such as "--output_mode EMIT_ALL_SITES"
	-help               print this message
	
	example:
	perl $0 -ref ref.fasta  -out_prefix Var/test -region 1AL:1-9607790  -bam sample*.bam
	
	SW\@KSU Dec.01.2012
###########################################################################################################################

);

die $sUsage unless @ARGV;

# predefined 
#my $samtools_bin = "/homes/bioinfo/bioinfo_software/samtools/samtools ";
my $bamutil = "/home/wangsc/Tools/bamUtil/bin/bam ";
#check_exec($bamutil);
my $samtools_bin = `module load SAMtools/0.1.19-intel-2015B; which samtools`;
chomp $samtools_bin;
#check_exec($samtools_bin);
my $picard_dir  = "/software/easybuild/software/picard/1.56-Java-1.7.0_80/";
##my $GATK_jar = "/home/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $GATK_jar = "/home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar ";
my ($ref_fasta, $out_prefix, $region, $MAX_THREADS, @bam_files, $help, $dcov, $gatk_params);
$MAX_THREADS = 1;
my $TMP;
GetOptions(
'ref=s'        =>	\$ref_fasta,
'nt=i'         =>	\$MAX_THREADS,
'region=s'     =>	\$region,
'out_prefix=s' =>       \$out_prefix,
'tmp=s'        =>       \$TMP,
'dcov=i'       =>       \$dcov,
'bam=s{1,}'    =>	\@bam_files,
'gatk=s'       =>       \$GATK_jar,
'params=s'     =>       \$gatk_params,
'help'         =>	sub{help()}
);


die $sUsage unless (defined $ref_fasta and defined $out_prefix and (@bam_files >=1) );

$dcov = 200 unless $dcov;
$GATK_jar = "/home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar " unless $GATK_jar; 

#print join("\n", ($ref_fasta, $out_prefix, $MAX_THREADS, @bam_files)), "\n"; exit;

print_time_stamp("Start GATK pipeline .....");
## index ref fasta
unless (-e $ref_fasta.".fai"){
	print_time_stamp("\tIndexing reference fasta file " . $ref_fasta);
	die "Index reference fasta failed \n" if system($samtools_bin . " faidx $ref_fasta");
	print_time_stamp("\tFinish indexing reference fasta file");
}
#
#print join("\t", @bam_files), "\n";
#
## add RG to bam file
#print_time_stamp("\tAdd RG to bam files ......");
#my @bams_addRG = map {basename($_, ".bam") . "_addRG.bam";} @bam_files;
#print join("\t", @bams_addRG), "\n";
##addRG(@bam_files);
#print_time_stamp("\tFinished ......");	
#
## sort bam files
#print_time_stamp("\tStart sorting bam files ......");
#my @sorted_bams = map {basename($_, ".bam") . "_sorted.bam";} @bams_addRG;
#print join("\t", @sorted_bams), "\n";
##sort_bam_files(@bams_addRG);
#print_time_stamp("\tFinish sorting bam files ......");	
#
## reassign mapping quality
#print_time_stamp("\tStarted reassigning mapping quality ......");
#my @bams_MQ= map {basename($_, ".bam") . "_MQ.bam"} @sorted_bams;
#print join("\t", @bams_MQ), "\n";
##reassign_mapping_quality_parallel($MAX_THREADS, @sorted_bams);
#print_time_stamp("\tFinished reassigning mapping quality ......");
#
## index bam files
#print_time_stamp("\tStart indexing bam files ......");
##index_bam_files(@sorted_bams);
#print_time_stamp("\tFinish indexing bam files ......");
#
## realignment, two steps
#print_time_stamp("\tStart realignment of bam files ......");
#my @realigned_bams = map {basename($_, ".bam") . "_realigned.bam";} @sorted_bams;
#print join("\t", @realigned_bams), "\n";
##GATK_realignment(@sorted_bams);
#print_time_stamp("\tFinish realignment of bam files ......");
#
## duplicate marking
#print_time_stamp("\tStart removing duplicates in bam files ......");
#my @rmdup_bams = map {basename($_, ".bam") . "_rmDup.bam";} @realigned_bams;
#print join("\t", @rmdup_bams), "\n";
##picard_duplicate_marking(@realigned_bams);
#print_time_stamp("\tFinish removing duplicates in bam files ......");
#
## reindex
#print_time_stamp("\tStart reindexing bam files ......");
##index_bam_files(@rmdup_bams);
#print_time_stamp("\tFinish reindexing bam files ......");


# SNP and Indel calling
print_time_stamp("\tStart calling variations from bam files ......");
my $raw_variation_vcf = variation_calling_haplotypecaller($gatk_params, @bam_files);
print_time_stamp("\tFinish calling variations from bam files ......");

# Variant Quality Score Recalibration, VQSR (not implmented yet)
#print_time_stamp("\tStart Variant Quality Score Recalibration ......");
#VQSR($raw_variation_vcf);
#print_time_stamp("\tFinish Variant Quality Score Recalibration ......");


# Done
#print_time_stamp("Finish GATK pipeline except VQSR.....");

# Subroutines
sub VQSR 
{

}


sub variation_calling
{
	my @recal_bams = @_;
	my @params = map{"-I ".$_} @recal_bams;
	my $out = $out_prefix . "_raw.snps.indels.vcf";
	my $cmd = "java -jar $GATK_jar -T HaplotypeCaller -R $ref_fasta -nt 20 ". join(" ", @params) . " -o $out";
  	die "!!! $cmd failed\n" if system($cmd);
  
  	return $out;
}

sub variation_calling_haplotypecaller
{
	my $gatk_params = shift;
        my @recal_bams = @_;
        my @params = map{"-I ".$_} @recal_bams;
        my $out = $out_prefix . "_raw.snps.indels.vcf";
	my $basedir = dirname($out); mkdir($basedir) unless -d $basedir;
        my $cmd = "java -Xmx30G  -jar $GATK_jar -T HaplotypeCaller -R $ref_fasta ". join(" ", @params) . " " . (defined $region?"-L $region ":" ") . " -o $out" . " -drf BadMate -drf DuplicateRead -U ALLOW_N_CIGAR_READS";
        $cmd  = $cmd . " " .  $gatk_params if $gatk_params;

  	die "!!! $cmd failed\n" if system($cmd);

	return $out;
}


sub base_recalibration
{
	my @rmdup_bams = @_;
	my @recal_bams;
	
	map{
		my $grp = basename($_, ".bam") . ".grp";
		
		# Step 1. Generates recalibration table, -T BaseRecalibrator
		my $cmd_a = "java -Xmx3g -jar $GATK_jar -T BaseRecalibrator -I $_  -R $ref_fasta -o $grp";
	  
	  print_time_stamp("\nRunning command: $cmd_a\n");
	  die "!!!\t$cmd_a failed\n" if system($cmd_a);
	  
	  # Step 2. print reads,  -T PrintReads
	  my $out_bam = basename($_, ".bam") . "_recal.bam";
	  my $cmd_b = "java -jar $GATK_jar -T PrintReads -R $ref_fasta -nt $MAX_THREADS -I $_  -BQSR $grp -o $out_bam";
   
   print_time_stamp("\nRunning command: $cmd_b\n");
   die "!!!\t$cmd_a failed\n" if system($cmd_b);
   
   push @recal_bams, $out_bam;
	  
	}@rmdup_bams;
	
	return @recal_bams;
}


sub picard_duplicate_marking
{
	my @realn_bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $merics_file = $_ . ".metrics";
		my $out = basename($_, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/MarkDuplicates.jar I=$_ O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
		push @picard_cmds, $cmd;
	}@realn_bams;
	
	run_parallel_jobs(\@picard_cmds, $MAX_THREADS);
	
	return @rmdup_bams;
}


sub GATK_realignment
{
	my @sorted_bams = @_;
	my @generate_interval_cmds;
	my @intervals;
	map {
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
	
	run_parallel_jobs(\@generate_interval_cmds, $MAX_THREADS);
	
	my @realigned_bams;
	my @realign_cmds;
	map{
		my $interval = $_ . ".intervals";
		my $realn_bam = basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		push @realign_cmds, $cmd;
	} @sorted_bams;

	run_parallel_jobs(\@realign_cmds, $MAX_THREADS);
	return @realigned_bams;
}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . " index " . $_;}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub reassign_mapping_quality
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $default_mapping_quality = 100;
	foreach my $bam (@bam_files)
	{
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
	}
		
}

sub reassign_mapping_quality_parallel
{
	my $max = shift;
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $pm = new Parallel::ForkManager($max);
	foreach my $bam (@bam_files)
	{
		$pm->start and next;
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
		
		$pm->finish;
	}
	
	$pm->wait_all_children;	
}


sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_prefix = basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . "sort -m 3000000000 $bam $sorted_prefix";
		push @sort_cmds, $cmd unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub addRG
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		my $id = basename($bam, ".bam");
		my $out = $id . "_addRG.bam";
		push @return, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$id LB=SeqCap ID=$id";
		push @cmds, $cmd;
	}
	run_parallel_jobs(\@cmds, $MAX_THREADS);
	return @return;
}

sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		print_time_stamp("\nRunning command: $cmd\n");
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}


sub print_time_stamp
{
        my $comments = shift;
        my $time = localtime();
        print STDERR $time, "\t", $comments, "\n";
}

sub help
{
	print $sUsage;
	exit;
}

			
