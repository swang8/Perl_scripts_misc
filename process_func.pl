#!/usr/bin/perl -w
use strict;
use File::Basename;
use File::Copy;
use Getopt::Long;
use Switch;
use lib '/home/wangsc/perl5/lib/perl5/';
use Parallel::ForkManager;

my $sUsage = qq(Usage:
perl $0
-func      function (options: samTobam, sortBam, addRG, removeDuplicates, localRealign, MQFilter)
-input     SAM/BAM files
-RG        Read group
-ref       reference in fasta format
-refindex  bowtie2 index basename
-outdir    The directory for output
-MAQ       mapping quality cutoff, default is 0
-CPU       number of CPUs that will be used to run bowtie2
);

##
##  PREDEFINED
my $bamutil = "/home/wangsc/Tools/bamUtil/bin/bam ";
check_exec($bamutil);
my $samtools_bin = `module load SAMtools/0.1.19-intel-2015B; which samtools`;
chomp $samtools_bin;
check_exec($samtools_bin);
my $picard_dir  = "/software/easybuild/software/picard/1.119-Java-1.7.0_80/";
my $GATK_jar = "/home/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $maq_cutoff = 0;
my $MAX_THREADS = 1;
## PREDEFINED END

my ( $ref_fasta, $ref_index, $input, $rg, $func, $outdir);
GetOptions(
					 'func=s'      => \$func,
					 'RG=s'        => \$rg,
					 'ref=s'       => \$ref_fasta,
					 'refindex=s'  => \$ref_index,
					 'outdir=s'    => \$outdir,
					 'input=s'     => \$input,
					 'CPU=i'       => \$MAX_THREADS,
					 'MAQ=i'       =>\$maq_cutoff
					 );
&check_required($func);
mkdir($outdir) if $outdir;

## subroutines need to generate these files
my %subroutines = (
"samTobam" => \&samTobam,
"sortBam" => \&sort_bam_files,
"addRG" => \&addRG,
"removingDuplicates" => \&picard_duplicate_marking,
"localRealign" => \&GATK_realignment,
"MQFilter" => \&quality_filter
);

## run
switch ($func) {
  case "samTobam" {
    unless ($input){die $sUsage};
    $subroutines{$func}->($input);
  }
  case "sortBam" {
    unless ($input){die $sUsage};
    $subroutines{$func}->($input);
  }
  case "addRG" {
    unless ($input and $rg){die "Need Input and RG!!\n\n" . $sUsage};
    $subroutines{$func}->($rg, $input);
  }
  case "removeDuplicates" {
    unless ($input){die $sUsage};
    $subroutines{$func}->($input);
  }
  case "localRealign" {
    unless ($input and $ref_fasta ){die "Need input and reference fasta!\n\n" . $sUsage};
    $subroutines{$func}->($input, $ref_fasta);
  }
  case "MQFilter" {
    unless ($input){die $sUsage};
    $subroutines{$func}->($input);
  }
  else {print "$func not defined!\n"; die $sUsage}
}

## finished
print_time_stamp("Finished.");


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
		print_time_stamp("\tStart removing duplicates in bam file $bam ......");
		&clean_sorted_bam($bam);
		my $merics_file = $bam . ".metrics";
		my $out = dirname($bam) . "/" . basename($bam, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx10G -jar $picard_dir/MarkDuplicates.jar I=$bam O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
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
	my $rg = shift;
        my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		print_time_stamp("add RG to bam file $bam");
		my $id = basename($bam, ".bam");
		my $out = dirname($bam). "/" . $id . "_addRG.bam";
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
sub check_required {
  my $func = shift; # samTobam, sortBam, addRG, removeDuplicates, localRealign, MQFilter
  die $sUsage unless $func;
  switch ($func) {
    case "samTobam" {
      unless ($input){die $sUsage} 
    }
    case "sortBam" {
      unless ($input){die $sUsage}
    }    
    case "addRG" {
      unless ($input and $rg){die "Need Input and RG!!\n\n" . $sUsage}
    }
    case "removeDuplicates" {
      unless ($input){die $sUsage}
    }
    case "localRealign" {
      unless ($input and $ref_fasta ){die "Need input and reference fasta!\n\n" . $sUsage}
    }
    case "MQFilter" {
      unless ($input){die $sUsage}
    }
    else {print "$func not defined!\n"; die $sUsage}
  } 
  
}
