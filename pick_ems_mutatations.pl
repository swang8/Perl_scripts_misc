#!perl -w
use strict;

my $wt_index = 11; # which column is the wt?

while(<>){
  if (/\#/){print $_; next}    
  my @t = split /\s+/,$_; 
  # skip indels
  next if length $t[3] > 1;
  my @p = split /,/, $t[4];
  my $flag=0;
  map{$flag=1 if length $_ > 1}@p;
  next if $flag;

  my %geno;
  my @alleles = split /,/, join(",", @t[3,4]);
  print STDERR join(" ", @alleles), "\n" if exists $ENV{DEBUG};
  foreach my $index (9 .. $#t){
    next if $t[$index]=~/\.\/\./;
    #my @codes = ($1, $2) if $t[$index]=~/^(\d)\/(\d)/;
    my @deps = ($1, $2) if $t[$index]=~/^[01]\/[01]:(\d+)\,(\d+)/;
    my @codes; map{push @codes, $_ if $deps[$_] >= 1 }0..$#deps;
    print STDERR join(" ", @codes), "\n" if exists $ENV{DEBUG};
    map{$geno{$index}{$alleles[$_]} = 1}@codes;
  }

# check
  next unless exists $geno{$wt_index}; # skip if missing data in wt
  my %mutation;
  foreach my $index(9..$#t){
    next if $index == $wt_index;
    next unless exists $geno{$index};
    my $mut = get_mutation_type($geno{$wt_index}, $geno{$index});
    $mutation{$index} = $mut if $mut eq "GA" or $mut eq "CT";
  }
  
  print $_ if keys %mutation > 0;
    
  
}


sub get_mutation_type {
  my $wt_hashref = shift;
  my $sam_hashref = shift;
  my @wt = keys %$wt_hashref;
  my @sam = keys %$sam_hashref;

  my @wt_uniq;
  map{push @wt_uniq, $_ unless exists $sam_hashref->{$_}}@wt;
  my @sam_uniq;
  map{push @sam_uniq, $_ unless exists $wt_hashref->{$_}}@sam;
  if (exists $ENV{DEBUG}){
    print STDERR "\@wt_uniq: ", join(" ", @wt_uniq ), "\n" if @wt_uniq;
    print STDERR "\@sam_uniq: ", join(" ", @sam_uniq ), "\n" if @sam_uniq;
  }
  if (@wt_uniq == 1 and @sam_uniq == 1){return $wt_uniq[0].$sam_uniq[0]}

  return "NA";

}
