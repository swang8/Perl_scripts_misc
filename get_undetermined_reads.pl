#!/usr/bin/perl -w
use strict;
use Getopt::Long;

my $sUsage = qq(
perl $0
  --undetermined  *.fq.gz
  --determined  *.fq.gz
  --output  output_name.fq.gz

Example:
  For undetermed read 1 (R1):  
  perl $0 --undetermined /data4/Processing/190115_K00333_0089_AH2LKGBBXY--20190119.225306/Data/Undeter*R1*gz --determined /data4/Processing/190115_K00333_0089_AH2LKGBBXY--20190119.225306/Data/18260Ibv/*.fastq.gz /data4/Processing/190115_K00333_0089_AH2LKGBBXY--20190122.143545/Data/18334Tho/*.fastq.gz --output undetermined_R1.fq.gz

);

my @undeter;
my @demuxed;
my $output_fqgz;
GetOptions(
  "undetermined=s{1,}" => \@undeter,
  "determined=s{1,}" => \@demuxed,
  "output=s" => \$output_fqgz
);

die $sUsage unless @undeter and @demuxed;

# out
open (my $OUT, "| gzip - >$output_fqgz") or die $!;

my %de_reads = read_demuxed_files(@demuxed);

foreach my $uf (@undeter){
  print_time("reading the undetermined file:", $uf);
  my $fh;
  if($uf =~ /gz$/){
    open($fh, "zcat $uf |") or die $!
  }
  else{
    open($fh, "cat $uf | ") or die $!
  }
  my $line = 0;
  my $flag = 0;
  while(<$fh>){
    $line++;
    if ($line==1){
      my $id = $1 if /^(\S+)/;
      $flag = 1 if exists $de_reads{$id};
    }
    print $OUT $_ unless $flag;
    if($line == 4){
      $line = 0;
      $flag = 0;
    }
  }
  close $fh;
}

close $OUT;

sub read_demuxed_files{
  my @files = @_;
  my %return;
  foreach my $uf (@files){
    print_time("processing file:", $uf);
    my $fh;
    if($uf =~ /gz$/){
      open($fh, "zcat $uf |") or die $!
    }
    else{
      open($fh, "cat $uf | ") or die $!
    }
    my $line = 0;
    while(<$fh>){
      $line++;
      if ($line==1){
        my $id = $1 if /^(\S+)/;
        $return{$id} = 1;
      }
      if($line == 4){
        $line = 0;
      }
    }
    close $fh;
  }
  return %return
}

sub print_time{
  my $t = localtime(time);
  my $msg = join(" ", @_);
  print STDERR $t, "\t", $msg, "\n";
}
