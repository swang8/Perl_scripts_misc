#!/usr/bin/perl -w
use strict;
use File::Basename;
use Getopt::Long;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;

my $sUsage = qq(
perl $0
-acc       Accession name
-reads     provide pairend reads (separate with comma) and/or single-end reads:  R1.fq,R2.fq  and/or single.fq
-ref       reference in fasta format
-refindex  bowtie2 index basename
-outdir    The directory for output
-MAQ       mapping quality cutoff, default is 0
-CPU       number of CPUs that will be used to run bowtie2
-bowtie2   The path to executable bowtie2: ie, /home/DNA/Tools/bowtie2/bin/bowtie2
);

##
# predefined 
my $samtools_bin = `which samtools`;
#my $samtools_bin = "samtools ";
my $picard_dir  = "/software/easybuild/software/picard/1.56-Java-1.7.0_80/";
my $GATK_jar = "~/Tools/GenomeAnalysisTK-2.2-8-gec077cd//GenomeAnalysisTK.jar ";

my (@read_files, $ref_fasta, $ref_index, $accession_name);
my ( $outdir, $MAX_THREADS) = ("./", 1); # default values
my $bowtie2_exec = `which bowtie2`; chomp $bowtie2_exec;
my $maq_cutoff = 0;

GetOptions('reads=s{1,}' => \@read_files,
					 'ref=s'       => \$ref_fasta,
					 'refindex=s'  => \$ref_index,
					 'bowtie2=s'   => \$bowtie2_exec,
					 'outdir=s'    => \$outdir,
					 'acc=s'       => \$accession_name,
					 'CPU=i'      => \$MAX_THREADS,
					 'MAQ=i'	=>\$maq_cutoff
					 );
die $sUsage unless (defined $ref_fasta and defined $ref_index);
die $sUsage unless @read_files > 0;

mkdir($outdir) if $outdir=~/\S/;

my @pair_reads = ([], []); 
my @single_reads;
map{
	chomp;
	my @p = split /,/, $_;
	if(@p == 2){
		push @{$pair_reads[0]}, $p[0];
		push @{$pair_reads[1]}, $p[1];
	}
	else{
		push @single_reads, $p[0]
	}
} @read_files;

## bt2 alignment
my $sam_file = $outdir . "/" .$accession_name . ".sam";
run_bowtie2($bowtie2_exec,$ref_index, $outdir, $accession_name, \@pair_reads, \@single_reads);
print_time_stamp("Finished alignment for accession $accession_name. The sam file is $sam_file\n");
###STOP
exit 0; ## stop here

## Processing steps
# samtobam
print_time_stamp("Convert SAM to BAM");
my $bam_file = $sam_file;
$bam_file =~ s/sam/bam/;
samTobam($sam_file);
&get_stat($bam_file);

## QC
print_time_stamp("\tStart removing low mapping Quality reads in bam file ......");
my $qc_bam = dirname($bam_file) . "/" . basename($bam_file, ".bam") . "_QC.bam";
print join("\t", $qc_bam), "\n";
&quality_filter($bam_file, $maq_cutoff);

index_bam_files($qc_bam);
#


## sort bam files
print_time_stamp("\tStart sorting bam file ......");
sort_bam_files($qc_bam);
my $sorted_bam = dirname($qc_bam) . "/". basename($qc_bam, ".bam") . "_sorted.bam";
print join("\t", $sorted_bam), "\n";
print_time_stamp("\tFinish sorting bam file ......");

# index bam files
print_time_stamp("\tStart indexing bam file ......");
index_bam_files($sorted_bam);
print_time_stamp("\tFinish indexing bam file ......");

#addRG
#print_time_stamp("add RG to bam");
#my $bam_addRG = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_addRG.bam";
#addRG($sorted_bam);
#print_time_stamp("\tFinished adding RG to bam file ......");
#


# realignment, two steps
print_time_stamp("\tStart realignment of bam file ......");
GATK_realignment($sorted_bam);
my $realigned_bam = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_realigned.bam";
print join("\t", $realigned_bam), "\n";
print_time_stamp("\tFinish realignment of bam file ......");


# duplicate marking
print_time_stamp("\tStart removing duplicates in bam file ......");
picard_duplicate_marking($realigned_bam);
my $rmdup_bam = dirname($realigned_bam) . "/" . basename($realigned_bam, ".bam") . "_rmDup.bam";
print join("\t", $rmdup_bam), "\n";
print_time_stamp("\tFinish removing duplicates in bam file ......");

# reindex
print_time_stamp("\tStart reindexing bam file ......");
index_bam_files($rmdup_bam);
print_time_stamp("\tFinish reindexing bam file ......\n");
sleep(60);
print_time_stamp("Finished all processing steps for accession $accession_name");

## Subroutines

sub quality_filter
{
  my $file = shift;
  my $maq = shift;
  my $out = dirname($file) . "/" . basename($file, ".bam") . "_QC.bam";
  open(IN, "$samtools_bin view -h -q $maq $file |") or die $!;
  open(OUT, "|$samtools_bin view -Sb - >$out") or die $!;
  while(<IN>){
    if(/^\@/){print OUT $_; next}
    my @t = split /\s+/,$_; 
    print OUT $_ if $t[6] eq '*' or $t[6] eq '=';
  }
  close IN;
  close OUT;
}

sub rm_overfloat
{
  my $file = shift;
  my $rm_file = dirname($file) . "/" . basename($file, ".bam") . "_rm.bam";
  my $MAX = 2**29 - 1;
  open(IN , "$samtools_bin view -h $file |") or die;
  open(OUT, "|$samtools_bin view -Sb - >$rm_file") or die;
  while(<IN>){
    if(/^\@/){print OUT $_; next}
    my @t = split /\s+/, $_;
    print OUT if $t[3] < $MAX and $t[7] < $MAX and $t[8] < $MAX;
  }

  close IN;
  close OUT;
  return $rm_file;
}


sub run_bowtie2
{
	# run_bowtie2($bowtie2_exec, $outdir, $accession_name, \@pair_reads, \@single_reads);
	my ($bowtie2, $refindex, $out, $acc, $pair_ref, $single_ref) = @_;
	print_time_stamp("Start runing bowtie2 alignemtn for acc $acc");
	my $cmd = "$bowtie2 -x $refindex ";
	if(@{$pair_ref->[0]} > 0){
		$cmd .=  " -1 ". join(",", @{$pair_ref->[0]}) . " -2 ". join(",", @{$pair_ref->[1]});
	}
	
	if (@{$single_ref} > 0){
		$cmd .= " -U ".join(",", @$single_ref);
	}
	
	my $sam = $outdir . "/" .$acc . ".sam";
	my $log = $outdir . "/". $acc . "_align.log";
	
	$cmd .= " --rg-id $acc --very-sensitive-local -p $MAX_THREADS -S $sam 2>$log";

	
	print_time_stamp("\t$cmd");
	die if system($cmd);
	return $sam;
}


sub samTobam
{
	my $file = shift or die $!;
	my $bam = $file;
	$bam=~s/sam$/bam/;
	my $cmd = "$samtools_bin  view -Shb $file  >$bam";
	die "$cmd failed !\n" if system($cmd);
	return $bam;
 }

sub picard_duplicate_marking
{
	my @realn_bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $merics_file = $_ . ".metrics";
		my $out = dirname($_) . "/" . basename($_, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx10G -jar $picard_dir/MarkDuplicates.jar I=$_ O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
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
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
	
	run_parallel_jobs(\@generate_interval_cmds, $MAX_THREADS);
	
	my @realigned_bams;
	my @realign_cmds;
	map{
		my $interval = $_ . ".intervals";
		my $realn_bam = dirname($_) . "/" . basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		push @realign_cmds, $cmd;
	} @sorted_bams;

	run_parallel_jobs(\@realign_cmds, $MAX_THREADS);
	return @realigned_bams;
}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . "index " . $_}@bam_files;
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


sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_prefix = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . "sort -m 3000000000 $bam $sorted_prefix";
		push @sort_cmds, $cmd #unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub sort_bam_files_picard
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_bam = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted.bam";
		push @return , $sorted_bam;
		my $cmd = "java -jar $picard_dir/SortSam.jar I=$bam O=$sorted_bam SO=coordinate";
		push @sort_cmds, $cmd;
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
		my $out = dirname($bam). "/" . $id . "_addRG.bam";
		push @return, $out;
		my $cmd = "java -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$id LB=SeqCap ID=$id VALIDATION_STRINGENCY=SILENT";
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
	


sub get_stat {

  my @bams = @_;
  foreach my $f( @bams){
    my $stat = $f. ".aln.stat.txt";
    my $cmd = "$samtools_bin flagstat $f >$stat";
    die "$cmd failed!\n" if system($cmd);
  }

}

