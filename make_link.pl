#!/usr/bin/perl -w
use strict;
use Cwd 'abs_path';

my $sUsage = qq(
Usage:
perl $0  <folder_contains_original_seq_files>  <destination_folder> <format: gz or fastq>  <flowcellname> <Lane>

An example:
Command:  perl $0  /mnt/data2/RAW_Data/KUMC_Jan_2015/C6319ACXX    /home/DNA/GBS_Analysis/fastq    gz  C6319ACXX  4
This command will link all the files in the folder /mnt/data2/RAW_Data/KUMC_Jan_2015/C6319ACXX to the folder /home/DNA/GBS_Analysis/fastq
and name the files as C6319ACXX_1_4_fastq.gz,  C6319ACXX_2_4_fastq.gz, C6319ACXX_3_4_fastq.gz, C6319ACXX_4_4_fastq.gz, ...

);

die $sUsage unless @ARGV == 5;

my ($org_dir, $des_dir, $format, $flowcell, $lane) = @ARGV;

unless(-d $des_dir){
  mkdir($des_dir) or die "Can not make dir $des_dir\n";
}

my $org_abs = abs_path($org_dir);
my $des_abs = abs_path($des_dir);

my @fs = glob "$org_abs/*";

foreach my $ind (0 .. $#fs){
  next if $fs[$ind]=~/csv$/;
  my $link_name = $flowcell . "_" . ($ind+1) . "_" . $lane."_fastq.txt";
  $link_name .= ".gz"  if($format =~ /gz/);
  my $link_cmd = "ln -s $fs[$ind] $des_abs/$link_name";
  die "can not make link to the file $fs[$ind]\n\t$link_cmd failed!!\n" if system($link_cmd);
}

exit;

