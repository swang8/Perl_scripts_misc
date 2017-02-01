#!/usr/bin/perl
use strict;
use lib "/home/shichen.wang/perl5/lib/perl5";
use Bio::DB::Fasta;

my ($ref, $var_file) = @ARGV;
die "perl $0 <ref.fasta>  <var>\n" unless @ARGV == 2;

my $gn = Bio::DB::Fasta->new($ref);

my @var = get_var($var_file);

foreach (@var){
  my ($ctg, $pos, $aa, $ab) = @$_;
  my $ctg_length = $gn->length($ctg);
  my $seq = $gn->seq($ctg, ($pos-2) => ($pos+2));
  my @ns = ();
  print STDERR $seq, "!\n";
  map{
    my $allele = $_;
    $seq =~ s/(\S{2})\S/$1$allele/;
    print STDERR $seq, "*\n";
    push @ns ,  &check_stop($seq);
  }($aa, $ab);
  
  @ns = unique(@ns);
  my @frames = map{my $p = $pos-2+$_-1; ($p%3)}@ns;
  my $stop = (@ns>0?"Y":"N");
  print join("\t", @$_, $stop, (@frames>0?(join(":", @frames)):"-")), "\n";
}

sub check_stop {
  my $str = shift;
  my %stop = map{$_, 1}qw(TAA TGA TAG);
  my @cnt = ();
  foreach my $ind (0 .. (length $str - 3)){
    my $codon = substr($str, $ind, 3);
    print STDERR $codon, "?\n";
    push @cnt, $ind if exists $stop{$codon};
  }
  return @cnt;
}


sub unique{
  my %h = map{$_, 1}@_;
  return sort{$a <=> $b} keys %h;
}

sub get_var{
  my $file = shift;
  my @return;
  open(IN, $file) or die $!;
  while(<IN>){
    chomp; 
    my @t = split /\s+/,$_; 
    next if length $t[2] >1 or length $t[3] > 1;
    push @return, [@t];
  }
  close IN;
  return @return;
}
