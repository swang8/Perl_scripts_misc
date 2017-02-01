#!/usr/bin/perl -w
use strict;
use File::Basename;
use File::Copy;
use Getopt::Long;
#use lib '/homes/wangsc/perl_lib';
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
my $bamutil = "/home/shichen.wang/Tools/bamUtil/bin/bam ";
check_exec($bamutil);
my $samtools_bin = "/util/opt/samtools/1.0/bin/samtools ";
check_exec($samtools_bin);
my $picard_dir  = "/util/opt/picard-tools/1.119/jar";
my $GATK_jar = "/home/shichen.wang/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";

my (@read_files, $ref_fasta, $ref_index, $accession_name);
my ( $outdir, $MAX_THREADS) = ("./", 1); # default values
my $bowtie2_exec = "/homes/wangsc/Tools/bowtie2/bowtie2";
my $maq_cutoff = 0;

##

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

## check steps that have been finished
my $latest_step = -2;
my $process_log = $outdir . "/$accession_name" . "_proc.log";
my $PROC; ## filehandle
if(-e $process_log){
  $latest_step = &get_latest_step($process_log);
  open($PROC, ">>$process_log") or die "can not open the file $process_log !\n"; 
}
else{
  open($PROC, ">$process_log") or die "can not open the file $process_log !\n";
}


## check sam
my $sam_file = $outdir . "/" .$accession_name . ".sam";
print STDERR "Previsous step finished: ", $latest_step, "\n";
if($latest_step > -2 ){
  print_time_stamp("Checking the sam file $sam_file is done!");
}
else{
  print_time_stamp("Checking the sam file $sam_file");
  if (simple_check($sam_file) eq "FAIL"){die "$accession_name alignment DID NOT FINISH Because the sam file $sam_file seems not complete!\n"}
  print_time_stamp("Checking the sam file $sam_file is done!");
  print $PROC "-1\n";  #output to the processing log file
}
## Files to be generated
my $bam_file = $sam_file; $bam_file =~ s/sam/bam/;
my $sorted_bam = dirname($bam_file) . "/". basename($bam_file, ".bam") . "_sorted.bam";
my $bam_addRG = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_addRG.bam";
my $rmdup_bam = dirname($bam_addRG) . "/" . basename($bam_addRG, ".bam") . "_rmDup.bam";
my $realigned_bam = dirname($rmdup_bam) . "/" . basename($rmdup_bam, ".bam") . "_realigned.bam";
my $qc_bam = dirname($realigned_bam) . "/" . basename($realigned_bam, ".bam") . "_QC.bam";

my @proc_files = ($sam_file, $bam_file, $sorted_bam, $bam_addRG, $rmdup_bam, $realigned_bam, $qc_bam);

## subroutines need to generate these files
# 1. samtobam; 2. sortbam; 3. addRg; 4. rmdup; 5.realign; 6. qc
my @subroutines = (
{"name" => "samTobam", "func" => \&samTobam},
{"name" => "SortBam", "func" => \&sort_bam_files },
{"name" => "addRG", "func" => \&addRG},
{"name" => "RemovingDuplicates", "func" => \&picard_duplicate_marking},
{"name" => "ReAlignment", "func" => \&GATK_realignment },
{"name" => "MappingQualityFiltering", "func" => \&quality_filter}
);

## start
my $step = 0;
my %step_failed = ();
while ($step <= $#subroutines){
	print_time_stamp("Running " . $subroutines[$step]->{"name"} .", step " . ($step+1) ." of " . (scalar @subroutines));
        unless($step > $latest_step){print_time_stamp($subroutines[$step]->{"name"} . " is done!"); $step++; next}
	my $input = $proc_files[$step];
	&index_bam_files($input) if $input =~ /bam$/;
	my $output = $proc_files[$step+1];
	#unless (simple_check($output) eq "FAIL"){print $PROC $step, "\n"; next}
	my $func = $subroutines[$step]->{"func"};
	$func->($input);
	sleep(60); # sleep 60 seconds
	if(rerun_if_need($output, $input, $func)){
	  $step_failed{$step} = 0 unless exists $step_failed{$step};
	  $step_failed{$step}++;
	  if($step_failed{$step} > 1){die "Step " . $subroutines[$step]->{"name"} . " failed more then once !\n"}
	  $latest_step--;
	  $step--;
	  if($step < 0){die "Sam to Bam failed!! Please check the SAM file: $sam_file !\n"}
	  next;
	}
	else{
	  print_time_stamp("Step " . $subroutines[$step]->{"name"} . " is done!");
          print $PROC $step, "\n";  # output to the processing log file.
	  $step++;
	}
}
&get_stat($bam_file);  # get the alignment stats
simple_check($qc_bam); # check the final bam file;
&index_bam_files($qc_bam);
## finished
print_time_stamp("Finished all processing steps for accession $accession_name");
close $PROC;


## Subroutines
sub clean_sorted_bam {
  my $bam = shift;
  print_time_stamp("\tStart cleaning the bam file $bam!");
  my $tmp="/tmp/" . basename($bam) . ".tmp" . time();
  open(my $IN, "$samtools_bin view -h $bam |") or die $!;
  open(my $OUT, "|$samtools_bin view -Sb - >$tmp") or die $!;
  my %pre=();
  while(<$IN>){
    next if /null/i;
    if(/^\@/){print $OUT $_; next}
    my @t = split /\s+/, $_;
    my $id = join(" ", @t[0,1]);
    next if exists $pre{$id};
    $pre{$id}=1;
    print $OUT $_;
  }
  close $IN;
  close $OUT;
  die "Cleaning $bam failed!\n" unless move($tmp, $bam);  
  print_time_stamp("\tFinished cleaning the bam file $bam!");
}


sub get_latest_step {
  my $file = shift;
  my $line = -2;
  if(-e $file){
    open(my $IN, $file) or die $!;
    while(<$IN>){
      chomp;
      $line = $1 if /^(\S+)$/;
    }
    close $IN;
  }
  return $line;
}

sub rerun_if_need {
  my $bam = shift;
  my $f_for_func = shift;
  my $func = shift;
  my $retry = 0;
  while(simple_check($bam) eq "FAIL"){
    $retry++;
    return 1 if $retry > 1;
    print_time_stamp("\tRetrying to generate $bam");
    $func->($f_for_func);
  }
  return 0;
}

sub simple_check
{
  my $file = shift;
  my $flag = 0;
  $flag = 1 if -e $file and validate_sam($file);
  return $flag?"PASS":"FAIL";
}


sub quality_filter
{
  my $file = shift;
  my $maq = $maq_cutoff;
  print_time_stamp("\tStart removing low mapping Quality reads in bam file $file ......");
  my $out = dirname($file) . "/" . basename($file, ".bam") . "_QC.bam";
  open(IN, "$samtools_bin view -h -q $maq $file |") or die "Couldn't open file $file\n";
  open(OUT, "|$samtools_bin view -Sb - >$out") or die "Couldn't open file $out\n";
  while(<IN>){
    print OUT $_;
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
	
	$cmd .= "--rg-id $acc --very-sensitive-local -p $MAX_THREADS -S $sam 2>$log";

	
	print_time_stamp("\t$cmd");
	die if system($cmd);
	return $sam;
}


sub samTobam
{
	my $file = shift or die $!;
	my $bam = $file;
	$bam=~s/sam$/bam/;
	print_time_stamp("Convert SAM to BAM");
	my $cmd = "$samtools_bin  view -Shb $file  >$bam";
	print STDERR  "$cmd failed !\n" if system($cmd);
	return $bam;
 }

sub picard_duplicate_marking
{
	my @bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $bam = $_;
		print_time_stamp("\tStart checking (not removed for GBS) duplicates in bam file $bam ......");
		&clean_sorted_bam($bam);
		my $merics_file = $bam . ".metrics";
		my $out = dirname($bam) . "/" . basename($bam, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx10G -jar $picard_dir/MarkDuplicates.jar I=$bam O=$out M=$merics_file REMOVE_DUPLICATES=false AS=true";
		print "$cmd failed \n" if system($cmd);
	}@bams;
}

sub validate_sam 
{
  # return o for notValidated; 1 for validated
  my $file = shift;
  my $out = $file . "_validation_output.txt";
  ##my $cmd = "java -Xmx10G -jar $picard_dir/ValidateSamFile.jar I=$_ O=$out IGNORE_WARNINGS=true VALIDATE_INDEX=false $additional";
  #my $cmd = "$samtools_bin view $file >/dev/null 2>$out";
  my $cmd = $bamutil . " validate --in $file --verbose 2>$out";
  if(system($cmd)){return 0}
  return 1;
}

sub GATK_realignment
{
	my @sorted_bams = @_;
	index_bam_files(@sorted_bams);
	my @generate_interval_cmds;
	my @intervals;
	map {
		print_time_stamp("\tStart realignment step 1 of bam file $_ ......");
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		print  "$cmd failed\n" if system($cmd);
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
		
	my @realigned_bams;
	my @realign_cmds;
	map{
		print_time_stamp("\tStart realignment step 2 of bam file $_ ......");
		my $interval = $_ . ".intervals";
		my $realn_bam = dirname($_) . "/" . basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		print  "$cmd failed\n" if system($cmd);
		push @realign_cmds, $cmd;
	} @sorted_bams;

}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . "index " . $_}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		print_time_stamp("\tStart sorting bam file $bam ......");
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
		print_time_stamp("add RG to bam file $bam");
		my $id = basename($bam, ".bam");
		my $out = dirname($bam). "/" . $id . "_addRG.bam";
		my $rg = $id;
		$rg =~ s/Sample_\S+_ExomeCapture/ExomeCapture/;
		push @return, $out;
		my $cmd = "java -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$rg LB=SeqCap ID=$rg VALIDATION_STRINGENCY=SILENT";
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

sub check_exec {
  my $exec = shift;
  $exec =~ s/\s//g;
  unless (-e $exec and -x $exec){
    die "$exec is not exists or not executable!\n";
  }
}
