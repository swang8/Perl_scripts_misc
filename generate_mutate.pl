#!/usr/bin/perl -w
use strict;
use lib '/home/shichen.wang/perl5/lib/perl5';
use lib '/home/shichen.wang/perl5/lib/perl5/x86_64-linux-thread-multi';
use Math::Random;
use Bio::DB::Fasta;

my $sUsage  = "perl $0 <fasta> <mutations per Kb, i.e.,  2 means 2 mutations per Kb>\n";
die $sUsage unless @ARGV == 2;

my ($file, $mutate) = @ARGV;
my %info;

my $db = Bio::DB::Fasta->new($file);
my @ids = $db->get_all_primary_ids;;

foreach my $id (@ids){
    print STDERR "chr, ", $id, "\n";
    my $seq = $db->seq($id);
    my $num_M = int(length($seq) / 1e6);
    $num_M ++ if length($seq) % 1e6;
    foreach my $ind (1..$num_M){
      my @mut_pos = random_uniform($mutate*1000,  ($ind-1)*1e6, ($ind*1e6 > length($seq)?length($seq):$ind*1e6));
      @mut_pos = map{int $_}@mut_pos;
      foreach my $p(@mut_pos){
          my $ref = substr($seq, $p-1, 1);
          my $mut_nuc = $ref;
          while($mut_nuc eq $ref){
            $mut_nuc = get_ATGC()    
          }
          substr($seq, $p-1, 1) = $mut_nuc;
          print STDERR join("\t", $id, $p, $ref, $mut_nuc),"\n";
      }
    }
    $seq =~ s/(\S{60})/$1\n/g;
    $seq =~ s/\s+$//;
    print ">", $id, "\n", $seq, "\n";
}

sub get_ATGC{
  my $r = int(rand(4));    
  return qw(A T G C)[$r];
}

