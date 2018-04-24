#!/usr/bin/perl -w
use strict;
my $sUsage = "perl $0 <hmp> <parent_A_columns: 56,57> <parent_B_clumns: 58,59>\n";
die $sUsage unless @ARGV == 3;

my $hmp = shift;
my $pa = shift;
my @pa_cols = split /,/, $pa;
my $pb = shift;
my @pb_cols = split /,/, $pb;

open(IN, $hmp) or die $!;
while(<IN>){
  if(/^rs/){print $_; next}
  chomp;
  my @t = split /\s+/,$_; 
  my @pa_geno = map{$t[$_-1]}@pa_cols;
  my @pb_geno = map{$t[$_-1]}@pb_cols;
  my %recode = recode([@pa_geno], [@pb_geno]);
  next unless (keys %recode) > 0;
  my @ab_geno = map{exists $recode{$_}?$recode{$_}:(/NN/?"-":"-")}@t[11..$#t];
  print STDERR $t[0],"\n";
  map{print STDERR $_, ": ", $recode{$_},"\n"}keys %recode;
  print STDERR join("\t", @t[11..$#t]), "\n", join("\t", @ab_geno),"\n\n";
  print join("\t", @t[0..10], @ab_geno),"\n"
}

sub recode {
  my ($pa, $pb) = @_;
  my %return;
  my %pa_allele = count_allele($pa);
  my $pa_ = join("", sort{$a cmp $b}keys %pa_allele);
  my %pb_allele = count_allele($pb);
  my $pb_ = join("", sort{$a cmp $b}keys %pb_allele);
  if($pa_ !~/\S/ or $pb_ !~/\S/ or $pa_ eq $pb_){return %return}
  my @pa_uniq = uniq([keys %pa_allele], [keys %pb_allele]);
  my @pb_uniq = uniq([keys %pb_allele], [keys %pa_allele]);
  if (@pa_uniq > 0 and @pb_uniq > 0) {
    $return{join("", @pa_uniq[0,0])}="A";
    $return{join("", @pb_uniq[0,0])}="B";
    $return{join("", $pa_uniq[0], $pb_uniq[0])} = "H";
    $return{join("", $pb_uniq[0], $pa_uniq[0])} = "H";
  }
  elsif (@pa_uniq){
    my $alt = alternative($pa_uniq[0], [keys %pa_allele, keys %pb_allele]);
    $return{join("", @pa_uniq[0,0])}="A";
    $return{join("", $pa_uniq[0], $alt)}="A";
    $return{join("", $alt, $pa_uniq[0])}="A";
    $return{join("", $alt, $alt)}="B";
    $return{join("", $alt, $pa_uniq[0])} = "H";
    $return{join("", $pa_uniq[0], $alt)} = "H";
  }
  elsif (@pb_uniq){
    my $alt = alternative($pb_uniq[0], [keys %pa_allele, keys %pb_allele]);
    $return{join("", @pb_uniq[0,0])}="B";
    $return{join("", $pb_uniq[0], $alt)}="B";
    $return{join("", $alt, $pb_uniq[0])}="B";
    $return{join("", $alt, $alt)}="A";
    $return{join("", $alt, $pb_uniq[0])} = "H";
    $return{join("", $pb_uniq[0], $alt)} = "H";
  }
  else{}
  return %return;
}

sub alternative {
  my $ref = shift;
  my $arr = shift;
  foreach(@$arr){
    return $_ if $_ ne $ref
  }
}

sub uniq {
  my $arr_a = shift;
  my $arr_b = shift;
  my %h = map{$_, 1}@$arr_b;
  my @return = grep{! exists $h{$_}}@$arr_a;
  return @return; 
}

sub count_allele {
  my $p = shift;
  my %return;
  map{unless(/N/){my @arr=split //, $_; foreach(@arr){$return{$_}++}}}@$p;
  return %return;
}


