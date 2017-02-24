#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;
use Parallel::ForkManager;
use Statistics::Descriptive;

# inputs
die "perl $0 <fasta> <kmer_size>\n" unless @ARGV == 2;
my ($fasta_file, $ksize) = @ARGV;

my $time = localtime(time);
print STDERR $time, "\t", "Starting ...\n";

## get the fasta file
my $fasta = Bio::DB::Fasta->new($fasta_file);
my @ids = $fasta->get_all_primary_ids;
my $max_threads = 10;

my $pm = Parallel::ForkManager->new($max_threads);

foreach my $id (sort{$a cmp $b} @ids){
  my $pid = $pm->start and next;
  my $t = localtime(time);
  print STDERR $t , "\t", "Processing $id ...\n";
  &get_kmer_positions($fasta, $id, $ksize);
  $pm->finish;
}
$pm->wait_all_children;
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
  my ($db, $id, $k) = @_;
  my $seq_len = $db->length($id);
  my $kmer_p = {};
  # for (my $i = 0; $i <= ($seq_len - $k); $i++){
  #   my $subseq = $db->seq($id, $i => ($i+$k-1));
  #   next if $subseq =~ /N/i;
  #   push @{$kmer_p->{$subseq}}, $i;
  # }
  my $fa = $db->get_Seq_by_id($id)->seq;
  while ($fa =~ /(\S{$k})/g){
    my $subseq = $1;
    ## print $subseq, "\n";
    next if $subseq =~ /N/i;
    push @{$kmer_p->{$subseq}}, pos($fa);
  }

  # output files
  my $summary = $id . "_kmer_summary.txt";
  my $freq = $id . "_frequency.txt";
  open (my $S, ">$summary")  or die "$summary failed to open!\n"; 
  open (my $F, ">$freq")  or die "$freq failed to open!\n"; 
  
  print $S "Chr ", $id, "\t", $seq_len, "\n";
  
  # calculate frequency
  foreach my $kmer (keys %{$kmer_p}){
    my @fragments;
    my $total_kmers = scalar @{$kmer_p->{$kmer}};
    next unless $total_kmers;
    my @read_len = (100, 150);
    my @covered_SE = map {$_ * $total_kmers} @read_len;
    foreach my $ind (0 .. ($total_kmers - 1)){
      if($ind == 0){push @fragments, $kmer_p->{$kmer}->[$ind]}else{push @fragments, ($kmer_p->{$kmer}->[$ind] - $kmer_p->{$kmer}->[$ind-1] + 1) };
    }
    print $S $kmer, "\t", $total_kmers, "\n";
    map{print $S $read_len[$_] , "bp SE read: ", $covered_SE[$_], "\n"} 0.. $#read_len;


    map{if($_ == 0){push @fragments, $kmer_p->{$kmer}->[$_]}else{push @fragments, ($kmer_p->{$kmer}->[$_] - $kmer_p->{$kmer}->[$_-1] + 1) }  } 0 .. (scalar @{$kmer_p->{$kmer}} - 1);
    my $stat = Statistics::Descriptive::Full->new();
    $stat->add_data(@fragments);
    my @bin = map{$_ * 100}2..10; @bin = (@bin, max(@fragments)) if max(@fragments) > 1000;
    my $f = $stat->frequency_distribution_ref(\@bin);
    for my $cutoff (sort {$a <=> $b} keys %$f) {
      print $F join("\t", $id, $kmer, $cutoff, $f->{$cutoff}), "\n";
    }
  }
  close $S;
  close $F;
}

sub max {
  my $m = shift;
  map{$m =$_ if $_ > $m}@_;
  return $m;
}
