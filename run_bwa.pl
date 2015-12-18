#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use File::Which;

my $sUsage = "perl $0 -acc accession_name  -r1 r1_1.fq,r1_2.fq,r1_3.fq  -r2 r2_1.fq,r2_2.fq,r2_3.fq  -s single1.fq,single2.fq -CPU 1\n";

die $sUsage unless @ARGV;


my ($acc, $r1, $r2, $single, $cpu);
$cpu = 1;

GetOptions(
  "acc=s" => \$acc,
  "r1=s" => \$r1,
  "r2=s" => \$r2,
  "s=s" => \$single,
  "CPU=i" => \$cpu
);

die $sUsage unless $acc and ( ($r1 and $r2) or $single);

my @r1_fq = split /,/, $r1;
my @r2_fq = split /,/, $r2;
die "Pair-end files are not matching \n" if $#r1_fq != $#r2_fq;


my @single_fq = split /,/, $single;

my $BWA = "bwa";
my $SAMTOOLS = "samtools";
unless(check_exec($BWA)){die "bwa executable is not found in " . join(" ", $ENV{PATH}). "\n"}
unless(check_exec($SAMTOOLS)){die "samtools executable is not found in " . join(" ", $ENV{PATH}) . "\n"}

my $picard_dir = "~/Tools/picard/";
message("Will try to use picard tools from this folder \"$picard_dir\"");
message("Checking picard ..");
if(-e $picard_dir . "MergeSamFiles.jar"){message("MergeSamFiles.jar is found.")}
else{message("Error: Not found MergeSamFiles.jar in the folder $picard_dir!"); die}

my @bams;
run_bwa([@r1_fq], [@r2_fq]);
run_bwa([@single_fq]);
message("Finished alignment for accesssion $acc");

# merge bams
merge_bams(@bams);
message("Merged all bams. The final bam file is ${acc}.bam");

##
sub check_exec {
  my $exec = shift;
  my $p = which $exec;
  return $p=~/\S/?1:0;
}

sub run_bwa {
  my @arr = @_;

  my $toBam = "$SAMTOOLS view -Sb - ";

  if ($#arr == 1){ ## pair-end
    my @fa = @{$arr[0]};
    my @fb = @{$arr[1]};
    foreach my $ind (0 .. $#fa){
      my $out = $acc. "_p".$ind.".bam";
      my $cmd = "$BWA mem -M -t $cpu $fa[$ind] $fb[$ind] | $toBam >$out";
      message($cmd , "started");
      die if system($cmd);
      message($cmd , "finished");
      push @bams, $out;
    }
  }

  if ($#arr == 0){ ## single-end
    my @fa = @{$arr[0]};
    foreach my $ind(0..$#fa){
      my $out = $acc . "_single${ind}.bam";
      my $cmd = "$BWA mem -M -t $cpu $fa[$ind] | $toBam >$out";
      message($cmd , "started");
      die if system($cmd);
      message($cmd , "finished");
      push @bams, $out;
    }
  }
  
}

sub merge_bams{
  my @files = @_;
  my $str = join(" ", @files);
  my $out = $acc. ".bam";
  my @params = map{"I=".$_} @files;
  my $cmd = "java -Xmx4G -jar ${picard_dir}MergeSamFiles.jar " . join(" ", @params) . " O=$out CO=\"".$str."\"";
  message($cmd, "started");
  die "Failed $cmd\n" if system($cmd); 
  message("$cmd finished");
}

sub message{
  my $str = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $str, "\n";
}
