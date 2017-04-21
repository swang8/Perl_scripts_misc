#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;
use Parallel::ForkManager;
use Statistics::Descriptive;

# inputs
die "perl $0 <fasta (txt or zipped)> <kmer_size>\n" unless @ARGV == 2;
my ($fasta_file, $ksize) = @ARGV;

my $max_threads = 10;

my $time = localtime(time);
print STDERR $time, "\t", "Starting ...\n";
if ($fasta_file =~ /gz$/){
  my $unzipped = $fasta_file;
  $unzipped =~ s/.gz$//;
  unless (-e $unzipped){
    die $! if system("gunzip -c $fasta_file >$unzipped");
  }
  $fasta_file = $unzipped;
}

## get the fasta file
my $fasta = Bio::DB::Fasta->new($fasta_file);
my @ids = $fasta->get_all_primary_ids;
@ids = grep{!/\D/}@ios;
my $pm = Parallel::ForkManager->new($max_threads);

my @pos_files;

foreach my $id (sort{$a cmp $b} @ids){
  my $out = $fasta_file . "_" . $id . "_${ksize}mer_pos.txt";
  push @pos_files , $out;
  my $pid = $pm->start and next;
  my $t = localtime(time);
  print STDERR $t , "\t", "Processing $id ...\n";
  &get_kmer_positions($fasta_file, $fasta, $id, $ksize, $out);
  $pm->finish;
}
$pm->wait_all_children;

# combine the output
my $combine = "cat " . join(" ", @pos_files) . " > " . $fasta_file . "_${ksize}mer_pos.txt";
die if system($combine);
map{unlink($_)}@pos_files;
$time = localtime(time);
print STDERR  $time ,"\t", "Done!!!\n";
##
sub kmer_generator {
  my $k = shift;
  my @bases = qw(A T G C);
  my @words = @bases;
  for (my $i = 1; $i < $k; $i++){
    # print "\$i: ", $i, "\n";
    my @newwords;
    foreach my $w (@words){
      foreach my $n (@bases){
        push @newwords, $w.$n;
	#print $w.$n, "\n";
      }
    }
    @words = @newwords;
  }
  return @words;
}

sub get_kmer_positions {
  my ($fasta_file, $db, $id, $k, $out) = @_;
  my $seq_len = $db->length($id);
  my $kmer_p = {};
  open (my $O, ">$out") or die $!; 
  for (my $i = 0; $i <= ($seq_len - $k); $i++){
    my $subseq = $db->seq($id, $i => ($i+$k-1));
    $subseq = uc($subseq);
    next if $subseq =~ /[^ATGC]/;
    $kmer_p->{$subseq} = [] unless exists $kmer_p->{$subseq};
    push @{$kmer_p->{$subseq}}, $i;
  }
  map{my $subseq=$_; print $O join(",", $id, $subseq,@{$kmer_p->{$subseq}}), "\n"}keys %{$kmer_p};
  close $O
}

sub max {
  my $m = shift;
  map{$m =$_ if $_ > $m}@_;
  return $m;
}
