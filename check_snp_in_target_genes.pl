#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
perl $0
<gff3 file shows the cordinate of transcripts>
<vcf file>
);
die $sUsage unless @ARGV == 2;
my ($gff_file, $vcf_file) = @ARGV;

my %transcripts_vec = read_gff3($gff_file);

open (V, $vcf_file) or die;
while(<V>){
	next if /^\#/;
	my @t = split /\s+/, $_;
	my ($chr, $snp_pos) = @t[0, 1];
	my $index = search($transcripts_vec{$chr}, $snp_pos);
	unless($index =~ /NA/){
	  print join("\t", @t[0,1], $transcripts_vec{$chr}->[$index][-1]), "\n"
	}
}
close V;

# Subroutine
sub search{
    my ($arr_ref, $pos) = @_;
    my $leng = scalar @$arr_ref;
    #my ($ctg, $s, $e);
    #binary search
    my $start_index = 0;
    my $end_index = $leng - 1;
    my $index = int(($start_index + $end_index)/2);
    while($end_index >= $start_index){
        my ($s, $e) = @{$arr_ref->[$index]};
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
    return "NA";
}


sub read_gff3{
	my $file = shift or die;
	open (IN, $file) or die;
	my %return;
	while (<IN>){
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      31152   31418   .       +       .       ID=chain_1;Target=asmbl_1 1 267 +
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      82474   82524   .       +       .       ID=chain_2;Target=asmbl_2 1 51 +
		#3AL     alignAssembly-pasa_flowsort_chr_3       cDNA_match      82604   82667   .       +       .       ID=chain_2;Target=asmbl_2 52 115 +

		next unless /\S+/;
		my @t = split /\s+/, $_;
		next unless $t[2] eq "gene";
		my $gid = $1 if /ID=(\S+)/;
		my ($chr, $start, $end) = ($t[0], sort{$a<=>$b} @t[3,4]);
		push @{$return{$chr}}, [$start, $end, $gid]
	}
	close IN;
	
        foreach my $chr(keys %return){
	  my @p = sort {$a->[0] <=> $b->[0]} @{$return{$chr}};
	  $return{$chr} = [@p]
	}

	return %return;
}
