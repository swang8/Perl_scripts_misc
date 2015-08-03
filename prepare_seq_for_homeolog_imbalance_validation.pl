#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;

my $sUsage = qq(
perl $0
<all9line fasta file>
<A_B_D_allele.out>
<Stephens_B_sil_Truman_nonsil.list.count_HSV>
<Truman_B_sil_Stephen_nonsil.list.count_HSV>
);

die $sUsage unless @ARGV >= 4;

my ($fasta_file, $hss_list, @list_files) = @ARGV;
my @arr = qw(B A D);

my $gn_obj = Bio::DB::Fasta->new($fasta_file);
my %hss_alleles = read_hss_list($hss_list);

foreach my $f(@list_files)
{
	my $out = $f . "_ABD.fasta";
	open (IN, $f) or die "can't open file $f\n";
	open (OUT, ">$out") or die "can't open file $out\n";
	my $count = 0;
	while(<IN>)
	{
		# BobWhite_mira1_rep_c48890       90
		chomp; 
		my @t = split /\s+/, $_;
		$count ++;
		my $seq = $gn_obj->get_Seq_by_id($t[0])->seq;
		my @abd_seq = generate_abd_seq($seq, $hss_alleles{$t[0]});
		my @positions;
		foreach (keys %{$hss_alleles{$t[0]}})
		{
			my @arr = split //, $hss_alleles{$t[0]}{$_};
			push @positions, $_ if $arr[0] eq $arr[2];
		}
		
		next unless @positions >= 3;
		my @dist = map{$positions[$_] - $positions[$_-1]}1..$#positions;
		my $flag = 1;
		map{$flag=0 if $_<=30}@dist;
		
	#	next if $flag;		
		
		foreach (0..$#abd_seq)
		{
			print OUT ">", $t[0], "_",$arr[$_], "_", join("-", sort{$a<=>$b}@positions), "\n";
			print OUT $abd_seq[$_], "\n";
		}
	}
	close IN;
	close OUT;	
}

# Subroutines
sub read_hss_list
{
	my $file = shift;
	my %return;
	open (IN, $file) or die $!;
	while(<IN>)
	{
		#tplb0058o18     1131    C       C       T
		chomp; 
		my @t = split /\s+/, $_;
		$return{$t[0]}{$t[1]} = join("", @t[2..4]);
	}
	close IN;
	return %return;
}

sub generate_abd_seq
{
	my ($seq, $hash_ref) = @_;
	my @return = ($seq, $seq, $seq);
	
	foreach my $pos (keys %$hash_ref)
	{
		my @alleles = split //, $hash_ref->{$pos};
		@alleles = @alleles[1,0,2];
		foreach my $index (0..$#alleles)
		{
			substr($return[$index], $pos-1, 1) = $alleles[$index];
		}
	}
	return @return;	
}












