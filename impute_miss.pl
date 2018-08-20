#!/usr/bin/perl -w
use strict;
use lib '/home/wangsc/perl5/lib/perl5';
use File::Basename;
use Parallel::ForkManager;

my $sUsage = "perl $0  <in_vcf>  <beagle_jar> <file_for_ordering_markers, optional>\n";
my $in_vcf = shift or die $sUsage;
my $jar = shift or die $sUsage;

my $order_file = shift or "";
## $order_file = "/home/wangsc/scratch_fast/Projects/GBS/wheat/ref_data/wheat_CSS/All_chr_flowsort-contigs_mapped_on_Ensembl-ref.txt_replace_NonCaoncatenated" unless $order_file;

my $ordered_vcf = $in_vcf; 
$ordered_vcf = order_markers($order_file, $in_vcf) if  $order_file =~ /\S/;

impute_missing($ordered_vcf, $jar);

##
sub print_time_stamp {
  my $str = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $str;
}

sub order_markers {
  my $order = shift;
  my $vcf = shift;
  if (not defined $order){return $vcf}
  my %ctg_pos = get_contig_pos($order);
  my $ord_vcf = basename($vcf);
  if($ord_vcf=~/.vcf$/){$ord_vcf=~s/\.vcf$/_ordered\.vcf/;}else{$ord_vcf = $ord_vcf . ".ordered"}
  open(OUT, ">$ord_vcf") or die "can not open file $ord_vcf!!";
  open(IN, $vcf) or die $!;
  my @arr;
  while(<IN>){
    if(/^\#/){print OUT $_; next}
    chomp;
    my @t = split /\s+/,$_; 
    my ($ctg, $pos) = @t[0,1];
    next if $t[3]=~/[^ATGCN]/ or $t[4] =~ /[^ATGCN]/;
    next unless exists $ctg_pos{$ctg};
    $t[2] = join(":", @t[0,1]);
    $t[0] = $ctg_pos{$ctg}[0];
    $t[1] = $pos + $ctg_pos{$ctg}[1] - 1;
    push @arr, [@t];
  }
  
  map {
    print OUT join("\t", @$_), "\n";
  } sort{$a->[0] cmp $b->[0] or $a->[1] <=> $b->[1]} @arr;  

  close OUT; 
  close IN;
  return $ord_vcf;
}

sub get_contig_pos{
  my $order_file = shift;
  open(my $IN, $order_file) or die $!;
  my %return;
  while(<$IN>){
    chomp;
    my @t = split /\s+/,$_;
    $return{$t[0]} = [@t[1,2]]
  }
  close $IN;
  return %return;
}

sub impute_missing {
  my $vcf = shift;
  my @chrs = get_chr($vcf);
  @chrs = grep {/\d/} @chrs;
  my $jar = shift;
  my $pm = Parallel::ForkManager->new(4); ## max 4 threads
  LOOP:
  foreach my $chr (@chrs) {
    $pm->start and next LOOP; # do the fork
    my $out = $chr . "_imputed";
    my $cmd = "java -Xmx8G -jar $jar gtgl=$vcf out=$out  niterations=10 gprobs=true lowmem=true chrom=$chr";
    print STDERR $cmd, "\n";
    system($cmd);
    $pm->finish; # do the exit in the child process
  }
  $pm->wait_all_children;
}

sub get_chr{
  my $vcf = shift;
  open(IN, $vcf) or die $!;
  my %return;
  while(<IN>){
    next if /^\#/;
    my $chr = $1 if /^(\S+)/;
    $return{$chr}=1
  }
  close IN;
  return keys %return;

}
