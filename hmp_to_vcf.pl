#!/usr/bin/perl -w
use strict;

my $hmp_file = shift or die "perl $0 hmp_file\n";
my @arr;
open(IN, $hmp_file) or die $!;
while(<IN>){
	chomp;
	my @t = split /\s+/, $_;
	if(/^rs/){
		print '##fileformat=VCFv4.1', "\n";
		print join("\t", "\#CHROM",  qw(POS     ID      REF     ALT     QUAL    FILTER  INFO    FORMAT) )
		      ,"\t", join("\t", @t[11..$#t]), "\n";
		next
	}
	my %allele_cnt;
	map{
		unless(/N/){
		  my @p = split //, $_;
		  map{$allele_cnt{$_}++ }@p;
		}
	}@t[11..$#t];
	my @alleles = sort {$allele_cnt{$b} <=> $allele_cnt{$a}} keys %allele_cnt;
	next unless @alleles == 2;
	my @geno = ();
	map{if(/N/){push @geno, "./."}elsif(/$alleles[0]/){push @geno, "0/0:1,0,0"}elsif(/$alleles[1]/){push @geno, "1/1:0,0,1"}else{push @geno, "0/1:1,1,0"} }@t[11..$#t];
	$t[3] = 1 if $t[3] <= 0;
	$t[3] = int($t[3] * 100000);
	##print join("\t", @t[2,3,0], @alleles, ".", ".", ".", "GT:PL", @geno), "\n";
	push @arr, [ @t[2,3,0], @alleles, ".", ".", ".", "GT:PL", @geno ];
}
close IN;

@arr = sort{$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]}@arr;
my ($chr, $pre_pos) = (0, 0);
map{
  my @p = @$_;
  if($p[0] == $chr){
    if($p[1] <= $pre_pos){$p[1] = $pre_pos + 1;}
    $pre_pos = $p[1];
  }
  else
  {
    $chr = $p[0];
    $pre_pos = $p[1];
  }
  print join("\t", @p), "\n";
}@arr;
