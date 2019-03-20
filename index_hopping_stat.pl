#!/usr/bin/perl -w
use strict;

my $sUsage = "perl $0 <input_fq_gz> <sample_sheet>\n";
die $sUsage unless @ARGV >= 2;

my ($fqgz, $csv) = @ARGV;

&time_stamp("\tStart reading csv", $csv);
my %barcodes = read_sample_sheet($csv);
&time_stamp("\tFinished reading csv", $csv);

# read fastq.gz

open(IN, "gunzip -c $fqgz | ") or die $!;
my $total = 0;
my $total_valid = 0;
my $total_valid_hopping = 0;
my $total_valid_correct = 0;

my $line = 0;
my $k = 0;
while(<IN>){
  $line++;
  if($line==1){ 
    # @A00180:23:HH3NJDSXX:2:1101:22752:1000 1:N:0:TCTTCCGA+GGTTACAA
    $k++; if($k % 1000000 == 0){&time_stamp("Processed", $k, "reads ...")}
    my $index_str = $1 if /([ATGNC]+\+[ATGNC]+)$/;
    my @p = split /\+/, $index_str;
    $total++;
    if (exists $barcodes{p7}{$p[0]} and exists $barcodes{p5}{$p[1]}){
      $total_valid++;
      if (exists $barcodes{comb}{$index_str}){ $total_valid_correct++ }
      else{ $total_valid_hopping++ }
    }
  }
  $line = 0 if $line==4; # reset
}

close IN;
print join("\t", qw(Total Not_valid Valid_correct Valid_hopping)), "\n";
print join("\t", $total, ($total - $total_valid), $total_valid_correct, $total_valid_hopping), "\n";


### subroutines;

sub time_stamp {
  my $msg = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $msg, "\n";; 
}

sub read_sample_sheet {
  my $f = shift;
  open(V, $f) or die $!;
  my %return;
  while(<V>){
    my @t = split /,/, $_;
    # Flowcell,Lane,Project,Sample,Barcode,RawClusterCount,PfClusterCountOriginal,AdapterClusterCount,TopBLAST,PfClusterCount,Chech / 2,Dif,Check,OK?
    # HH3NJDSXX,2,18192Wal,5557_Mea,ACATCGGA+GAAGTTGA,15419889,15419889,,,10319293,7709944.5,0.49427766, 5557_Mea , -
    my $indexes = $t[4];
    next unless $indexes and  $indexes =~ /\+/;
    $return{comb}{$indexes}=1;
    my @p = split /\+/, $indexes;
    $return{p7}{$p[0]}=1;
    $return{p5}{$p[1]}=1;

    # allow one mismatches
    foreach my $i (0..(length $p[0]) - 1){
      my $p7 = $p[0];
      my @p7m = map{substr($p7, $i, 1) = $_; $p7}qw(A T G C);
      map{ $return{p7}{$_}=1 } @p7m;
      foreach my $j(0..(length $p[1]) - 1){
        my $p5 = $p[1];
        my @p5m = map{substr($p5, $i, 1) = $_; $p5}qw(A T G C);
        map{ $return{p5}{$_}=1 } @p5m;
        foreach my $tmp(@p7m){
          map{ $return{comb}{join("+", $tmp, $_)}=1 }@p5m;
        }
      }
    }
  }
  close V;
  return %return;
}
