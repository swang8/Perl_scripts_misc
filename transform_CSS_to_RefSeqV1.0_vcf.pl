#!/usr/bin/perl -w
use strict;
use LWP::Simple;

my $bed = "http://download.txgen.tamu.edu/shichen/CSS_to_pseudoMV1.0_coord.bed";
my @vcfs = @ARGV or die "perl $0 vcf_files\n";
my %coord = get_coordinate($bed);
foreach my $vcf (@vcfs){
  print STDERR $vcf, "\n";
  open(V, $vcf) or die $!;
  while(<V>){
      if(/\#/){next}
      chomp;
      my @t = split /\s+/,$_;
  # 3967255_1al     2478  .     C       T       2950.31
      $t[2] = join(":", @t[0,1]) if $t[2] eq ".";
      if(exists $coord{$t[0]}){
          my @arr = @{$coord{$t[0]}};
          my $strand = $arr[4] < $arr[5]?1:-1;
          my $new_pos = $arr[4] + $strand * ($t[1] - $arr[1]);
          $t[0] = $arr[3];
          $t[1] = $new_pos;
      }
      print join("\t", @t),"\n"
  }
  close V;
}
##
sub get_coordinate {
    my $bed = shift;
    my $bed_ = get $bed;
    my %return;
    open(BED, "<", \$bed_) or die $!;
    while(<BED>){
        chomp;
        my @t = split /\s+/,$_;
        # 46_1al  1       71      chr1A   191733759       191733829
        print STDERR $t[0],"\n" if $ENV{DEBUG};
        $return{$t[0]} = [@t]
    }
    close BED;
    return %return;
}
