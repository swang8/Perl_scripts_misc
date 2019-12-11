#!perl -w
use strict;

my $sUsage = qq(
perl $0 <original_vcf> <random_NA_vcf> <NA_loci_file> <impted_vcf>
);
die $sUsage unless @ARGV == 4;

my ($orig_vcf, $na_vcf, $loci_file, $imp_vcf) = @ARGV;

my %orig_hash = read_vcf($orig_vcf);
my %na_hash = read_vcf($na_vcf);
my %imp_hash = read_vcf($imp_vcf);

my %loci = read_loci_file($loci_file);

print join("\t", qw(Frequency GP orig_geno imp_geno Correct)), "\n";
foreach my $k (keys %loci){
  next unless exists $imp_hash{$k};
  next unless exists $orig_hash{$k};
  my @orig_data = @{$orig_hash{$k}};
  my %orig_freq = count(@orig_data[9..$#orig_data]);
  my @loc = @{$loci{$k}};
  foreach my $l (@loc){
    print STDERR join("\t", $orig_hash{$k}->[$l], $na_hash{$k}->[$l], $imp_hash{$k}->[$l]), "\n";
    my $orig_geno = get_geno($orig_hash{$k}->[$l]);
    next if $orig_geno =~ /\./;
    my $imp_geno = get_geno($imp_hash{$k}->[$l]);
    my $GP = get_gp($imp_hash{$k}->[$l]);
    print join("\t", $orig_freq{$orig_geno}, $GP,$orig_geno, $imp_geno, ($orig_geno eq $imp_geno?1:0)), "\n"
  }
}

#### Subs
sub get_geno {
  my $s = shift;
  $s =~ s/\|/\//;
  my @p = split /:/, $s;
  return $p[0]
}

sub get_gp {
  my $s = shift;
  my @p = split /:/, $s; 
  my @arr = split /,/, $p[-1];
  return max(@arr);
}

sub max{
  my @arr = @_;
  my $max = $arr[0];
  map{$max = $_ if $_ > $max}@arr;
  return $max;
}

sub count {
 my @arr = @_;    
 my %count;
 map{
   my @p = split /:/, $_;
   my $g = $p[0];
   $g =~ s/\|/\//;
   $count{$g}++ unless $g=~/\./;
 }@arr;
 my $tot = 0;
 map{$tot += $_}values %count;
 my %freq = map{$_, $count{$_}/$tot}keys %count;
 return %freq;
}


sub read_vcf {
  my $vcf = shift;
  open(V, $vcf) or die $!;
  my %return;
  while(<V>){
    chomp;
    next if /\#/;
    my @t = split /\s+/,$_; 
    die $vcf unless @t;
    $return{join("\t", @t[0,1])} =  [@t]
  }
  close V;
  return %return;
}

sub read_loci_file {
  my $f = shift;
  open(F, $f) or die $!;
  my %return;
  while(<F>){
    chomp;
    my @t = split /\s+/,$_;
    $return{join("\t", @t[0,1])} = [@t[2..$#t]]
  }
  close F;
  return %return;
}
