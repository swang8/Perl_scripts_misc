#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use File::Basename;

my $fastq_file; 
my $qc_pl;
my $aln_pl;
my $call_pl;
my $REF;
my $REFINDEX;
my $num_jobs;
my $job_name;

GetOptions (
"fq_List=s"   => \$fastq_file,
"numJobs=i" => \$num_jobs,
"jobName=s" => \$job_name,
"qc_pl=s" => \$qc_pl,
"aln_pl=s"  => \$aln_pl,
"call_pl=s" => \$call_pl,
"ref=s"     => \$REF,
"refindex=s" => \$REFINDEX
);

sub help {
print qq(
perl $0
  -fq_list fastq_list.txt  # list of fastq files, first column is the accession name, second column is the full path to the fastq file (fastq or gzfastq);
  -numJobs  10             # how many jobs to be submitted to the HPC
  -jobName  myJob          # The name of job
  -aln_pl   /home/$ENV{USER}/pl_scripts/align.pl
  -call_pl  /home/$ENV{USER}/pl_scripts/unifiedgenotyper.pl
  -ref      /home/$ENV{USER}/scratch_fast/ref_data/Dgenome/Dgenome.fa
  -refindex /home/$ENV{USER}/scratch_fast/ref_data/Dgenome/Dgenome_bt2_index

Once the bsub scripts are generated, run "ls *.bsub |perl submit_sequential_jobs.pl" to submit all the jobs.
); 
}

unless ($fastq_file and $REF and $REFINDEX) {
  &help();
  exit;
}

open (IN, $fastq_file) or die "Error: can not open $fastq_file\n";

$num_jobs = 10 unless $num_jobs;

$job_name = "bsubjob" unless $job_name;

my %h;
while(<IN>){
  chomp;
  my @t = split /\s+/,$_;
  unless ($t[1] =~ /^\//){die "Error: require absolute path for fastq files\n"}
  map{ $h{$_} = $t[0] }@t[1..$#t];
}
close IN;
time_stamp("done reading fastq list file");
#
$qc_pl = "/home/$ENV{USER}/Tools/NGSQCToolkit_v2.3.3/QC/IlluQC.pl" unless defined $qc_pl;
my @arr = grep{!/R2/} keys %h;

my @params; 
foreach my $f (@arr) {
  my $f2=$f; 
  $f2=~s/R1/R2/; 
  my $folder = dirname($f);
  my $qc_folder = $folder . "/QC";
  my $acc = $h{$f};
  mkdir $qc_folder unless -d $qc_folder;
  if(exists $h{$f2}) {
    #push @params, "-pe $f $f2 2 5";
    my $cmd="java -jar \$EBROOTTRIMMOMATIC/trimmomatic-0.38.jar PE -threads 4 $f $f2 $qc_folder/${acc}_F.fq.gz  $qc_folder/${acc}_FU.fq.gz $qc_folder/${acc}_R.fq.gz $qc_folder/${acc}_RU.fq.gz ILLUMINACLIP:\$EBROOTTRIMMOMATIC/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36";
    push @params, $cmd;
  }
  else{
    #push @params, "-se $f 1 5"
     my $cmd="java -jar \$EBROOTTRIMMOMATIC/trimmomatic-0.38.jar SE -threads 4 $f  $qc_folder/${acc}_F.fq.gz  ILLUMINACLIP:\$EBROOTTRIMMOMATIC/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36";
     push @params, $cmd;
  }   
}
##
my $header = qq(#!/bin/bash
#
# See "man bsub" for more information on rusage
#
#BSUB -W 70:05                    # wall-clock time (hrs:mins)
#BSUB -L /bin/bash                # login shell    
#BSUB -n 1                        # number of tasks in job
#BSUB -R "span[ptile=1]"          # run one MPI task per node
#BSUB -R "rusage[mem=5000]"     # memory to reserve, in MB
#BSUB -J myjob                    # job name
#BSUB -o myjob.%J.%I.out             # output file name in which %J is replaced by the job ID
#BSUB -e myjob.%J.%I.err             # error file name in which %J is replaced by the job ID

module load zlib/1.2.8-intel-2015B
module load Java/1.8.0_181
export PERL5LIB="/home/wangsc/perl5/lib/perl5/x86_64-linux-thread-multi___/"  # modify this path to reflect your own setup
);


my $qc_header = $header;
# Generate bsub job script for QC
my $qc_bsub = "0.qc.bsub";
open(QB, ">$qc_bsub") or die $!;

my $num_param = int ( (scalar @params) / $num_jobs ) + 1;
$num_param++ if (scalar @params) % $num_jobs ;
$qc_header =~ s/-J\s+myjob/"-J ". $job_name . "_QC[1-$num_jobs]"/e;
$qc_header =~ s/myjob/$job_name . "_QC"/eg;
$qc_header =~ s/-n 1/-n $num_param/;
$qc_header =~ s/ptile=1/ptile=$num_param/;
print QB $qc_header, "\nmodule load Trimmomatic/0.38-Java-1.8.0\ndate\n";
print STDERR '$num_jobs: ', $num_jobs, "\n";
print STDERR '$num_param: ', $num_param, "\n";
foreach my $ind (1 .. $num_jobs){
  my $start = ($ind - 1) * $num_param;
  my $end = $start + $num_param - 1;
  $end = $#params if $end > $#params;
  my $cmd = join("\n", @params[$start .. $end]);
  print QB "if [ \$LSB_JOBINDEX  ==  $ind ]; then\n", $cmd, "\nfi\n\n";
  print STDERR "if [ \$LSB_JOBINDEX  ==  $ind ]; then\n", $cmd, "\nfi\n\n";
  last if $start >= $#params or $end >= $#params;
}

print QB "date\n echo \"Done \$LSB_JOBINDEX\"\n";
close QB;
time_stamp("generated $qc_bsub");

## Generate bsub job script for Alignment
my $aln_header = $header;
$aln_header =~ s/-n\s+\d+/-n 10/;
$aln_header =~ s/ptile=\d+/ptile=10/;
$aln_header =~ s/mem=\d+/mem=2000/;
my $aln_bsub = "1.aln.bsub";
open(ALN, ">$aln_bsub") or die $!;

my %acc_qc;
foreach (@params){
  my @p = split /\s+/,$_;
  my @fs = / PE /?@p[8..11]:$p[7];
  my $dir = dirname($fs[0]);
  my $acc = $h{$p[6]};
  if(@fs == 1){push @{$acc_qc{$acc}},  $fs[0]; next}
  my @filtered = @fs[0,2];
  #my $single_HQ = $dir . "/IlluQC_Filtered_files/" . basename($fs[0]) . "_" . basename($fs[1]) . "_unPaired_HQReads";
  push @{$acc_qc{$acc}}, join(",", @filtered);
  #push @{$acc_qc{$acc}}, $single_HQ if -e $single_HQ and not -z $single_HQ;
}
$aln_pl = "/home/$ENV{USER}/pl_scripts/align.pl" unless defined $aln_pl;
$REF="/home/$ENV{USER}/scratch_fast/Projects/GBS/wheat/ref_data/wheat_concate/Dgenome/Dgenome.fa" unless $REF;
$REFINDEX="/home/$ENV{USER}/scratch_fast/Projects/GBS/wheat/ref_data/wheat_concate/Dgenome/Dgenome.fa" unless $REFINDEX;
my $outdir = "Alignments"; mkdir($outdir) unless -d $outdir;
my $b2 = `module load Bowtie2/2.3.4.2-foss-2018b; which bowtie2`; 
my @aln_cmds;
map{
  my $acc = $_;
  my @fs = @{$acc_qc{$acc}};
  push @aln_cmds, "perl $aln_pl -acc $acc -reads " . join(" ", @fs) . " -ref $REF -refindex $REFINDEX -outdir $outdir -MAQ 5 -CPU 10 -bowtie2 $b2";
}keys %acc_qc;

my $start = 0;
my $index = 0;
my $total = int ((scalar @aln_cmds) / 10);
$total ++ if (scalar @aln_cmds) / 10;

$aln_header =~ s/myjob/$job_name."_ALN[1-$total]"/e;
$aln_header =~ s/myjob/$job_name."_ALN"/eg;
print ALN  $aln_header, "\nmodule load Bowtie2/2.3.4.2-foss-2018b\ndate\n";
while($start <= $#aln_cmds){
  $index ++;
  print ALN "if [ \$LSB_JOBINDEX == $index ]; then\n";
  my $end = $start + 9;
  $end = $#aln_cmds if $end > $#aln_cmds;
  print ALN join("\n", @aln_cmds[$start .. $end]), "\nfi\n\n";
  last if $end >= $#aln_cmds;
  $start = $end + 1; 
}
print ALN "date\necho \"done \$LSB_JOBINDEX\"\n";
close ALN;
time_stamp("generated $aln_bsub");
## generate bsub job script for processing
my $proc_bsub = "2.proc.bsub";
open(PB, ">$proc_bsub") or die $!;
open(IN, $aln_bsub) or die $!;
while(<IN>){
  s/-n\s+\d+/-n 1/;
  s/ptile=\d+/ptile=1/;
  s/mem=\d+/mem=8000/;
  s/align.pl/process_gbs.pl/;
  s/_ALN/_PROC/ if /^\#/;
  print PB $_;
}
close IN;
close PB;
time_stamp("generated $proc_bsub");
## genearte bsub job script for calling variations
$call_pl = "/home/$ENV{USER}/pl_scripts/unifiedgenotyper.pl" unless $call_pl;
my $call_bsub = "3.call.bsub";
open (CB, ">$call_bsub") or die $!;
my $call_header = $header;
$call_header =~ s/-n\s+\d+/-n 1/;
$call_header =~ s/ptile=\d+/ptile=1/;

my @chrs = get_chrs_from_fai($REF.".fai");
my $t = scalar @chrs;
$call_header =~ s/myjob/$job_name."_VAR[1-$t]"/e;
$call_header =~ s/myjob/$job_name."_VAR"/eg;
print CB $call_header, "\ndate\n";
my $var_dir = "Variations"; mkdir($var_dir) unless -d $var_dir;
my @bams = ("$outdir/*QC.bam");
foreach my $ind (0 .. $#chrs){
  my $job = $ind + 1;
  print CB "if [ \$LSB_JOBINDEX == $job ]; then\n ";
  print CB "perl $call_pl  -ref $REF -out_prefix Variations/$chrs[$ind] -region $chrs[$ind] -bam " . join(" ", @bams), "\n";
  print CB "fi\n\n";
}

print CB "date\necho \"done \$LSB_JOBINDEX\"\n";
close CB;
time_stamp("generated $call_bsub");

##
sub get_chrs_from_fai {
  my $f = shift;
  open(IN, $f) or die $!;
  my @return;
  while(<IN>){
    push @return, $1 if /^(\S+)/;
  }
  close IN;
  return @return;
}

sub time_stamp{
  my $s = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $s, "\n";
}
