#!/usr/bin/perl -w
use strict;
my $sUsage = "perl $0 [Contigs_coordiantes_in_concatenated]  [VCF]";
die $sUsage unless @ARGV >= 2;

my ($coord_file, @vcf_files) = @ARGV;

my %coord_hash = read_coordinates($coord_file);
foreach my $vcf_file (@vcf_files){
  open (IN, $vcf_file) or die;
  while(<IN>){
      chomp; 
      next if /^\#/;
      my @t = split /\s+/,$_;
      my ($chr, $pos) = @t[0, 1];
      my $total_dep = $t[2];
      my $index = search($coord_hash{$chr}, $pos);
      my ($contig, $start, $end) = @{$coord_hash{$chr}[$index]};
      my $newpos = $pos - $start +  1;
      print STDERR join("\t", (@t[0,1], $contig, $newpos)), "\n";
      print join("\t", ($contig, $newpos), @t[2..$#t]), "\n";
      #print STDERR join("\t", (@t[0,1], $contig, $newpos)), "\n";
  }
  close IN;
}
#
sub read_coordinates{
  my $file = shift;
  open (F, $file) or die;
  my %return;
  while(<F>){
    #2311680_1al     1AL     1       105
    my @t = split /\s+/,$_;
    push @{$return{$t[1]}}, [@t[0,2,3]];
  }
  close F;
  return %return;
}

sub search{
    my ($arr_ref, $pos) = @_;
    my $leng = scalar @$arr_ref;
    #my ($ctg, $s, $e);
    #binary search
    my $start_index = 0;
    my $end_index = $leng - 1;
    my $index = int(($start_index + $end_index)/2);
    while($end_index >= $start_index){
        my ($ctg, $s, $e) = @{$arr_ref->[$index]};
        if($s<=$pos and $e>=$pos){return($index)}
        if($s > $pos){
            $end_index = $index-1;
            $index = int(($start_index + $end_index)/2);
        }
        else{
            $start_index = $index+1;
            $index = int(($start_index + $end_index)/2);
        }
    }
}
