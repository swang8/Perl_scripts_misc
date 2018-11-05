#!/usr/bin/perl -w
use strict;
use File::Basename;

my $sUsage = qq(
perl $0 <input_file> <output_directory>
input_file should have bacterial names. One name on each line.
);

my $input = shift or die $sUsage;
my $out_dir = shift or die $sUsage;
mkdir($out_dir) unless -d $out_dir;
my @names = get_names($input);
my @refseq = get_refseq();

foreach my $n (@names){
  print "name: ", $n, "\n";
  my $dir = $out_dir . "/" . $n;
  $dir =~ s/\s+/_/g;
  mkdir($dir) unless -d $dir;
  my $ftp="";
  foreach my $f(@refseq){
    my @arr = @$f;
    next unless $arr[11] eq "Complete Genome";
    if($arr[7] =~ /$n/){
      $ftp = $arr[19];
      last
    }
  }
  unless ($ftp=~/\S/){warn "$n is not in the refseq!!"; next}
  print "Downloading $ftp";
  my $asmbl_name = basename($ftp);
  my $full_path = $ftp . "/" . $asmbl_name . "_genomic.fna.gz";
  my $outfile = $dir . "/" . "${asmbl_name}_genomic.fna.gz";
  system("wget -O - $full_path >$outfile") == 0
              or die "failed: $?";
  unless (-e "$outfile") {
  	warn "We don't have ${asmbl_name}_genomic.fna.gz, did download fail?";
  	next;
  }

}



sub get_names{
  my $f = shift;
  open(IN, $f) or die $!;
  my @return;
  while(<IN>){chomp; push @return, $_}
  close IN;
  return @return;
}


sub get_refseq{
    my @return;
    my $refseq_stat = "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/assembly_summary_refseq.txt";
    system("wget -O - $refseq_stat  >/tmp/refseq.txt");
    open(IN, "/tmp/refseq.txt") or die $!;
    while(<IN>){
        chomp;
        next if /^#/;
        my @t=split /\t/,$_;
        push @return, [@t]
    };
    close IN;
    return @return;
}

