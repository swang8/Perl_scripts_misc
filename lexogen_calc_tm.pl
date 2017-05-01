#!/usr/bin/perl -w
use lib '/home/shichen.wang/perl5/lib/perl5';
use Bio::SeqFeature::Primer;

my $sUsage = qq(
perl $0 <k>
);

my $k = shift or die $sUsage;

my @kmers = generate_kmer($k);

map{
  my $tm = get_tm($_);
  print $_, "\t", $tm, "\n"
}@kmers;

## 
sub get_tm {
    my $seq = shift;
    return unless $seq;
    my $p = Bio::SeqFeature::Primer->new( -seq => $seq );
    return $p->Tm_estimate;
}

sub generate_kmer {
    my $k = shift;
    my @bases  =qw(A T G C);
    my @return = @bases;
    while ($k > 1){
        $k--;
        my @arr = ();
        foreach my $pre (@return){map{push @arr, $pre . $_}@bases;}
        @return = @arr;
    }
    return @return;
}
