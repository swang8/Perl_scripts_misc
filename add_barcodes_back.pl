#!/usr/bin/perl -w
use strict;
my $sUsage = qq(
perl $0 <barcode_sequence> <fastq_files>
);

die $sUsage unless @ARGV >= 2;
my $seq = shift;
my @fq_files = @ARGV;
foreach my $f(@fq_files){
  my $FH;
  my $mode = "txt";
  if($f=~/gz/){
    $mode = "gz";
    open($FH, $f) or die "Can not open file $f\n";
  }
  else{
    open ($FH, "zcat $f |") or die "Can not open file $f\n";
  }
  print_time("Processing", $f);
  generate_fq( $FH, $f, $mode, $seq);
  close $FH;
  print_time("Finished", $f);
}
##
sub print_time{
  my $t = localtime(time);
  my $comment = join(" ", @_);
  print $t, "\t", $comment, "\n";
}
sub generate_fq {
  my ($fh, $f, $m, $barcode) = @_;
  my $out_file = $f . ($m=~/txt/?"_addBarcode.fq":"_addBarcode.fq.gz");
  my $OUT;
  if($m=~/txt/){open($OUT, ">$out_file") or die $!}
  else{open($OUT, "|gzip - >$out_file" ) or die $!}
  my $line = 0;
  while(<$fh>){
    $line++;
    if($line == 2){$_ = $barcode . $_}
    if($line == 4){$line = 0; my $qual = "A" x length($barcode); $_ = $qual . $_}
    print $OUT $_
  }
  close $OUT
}
