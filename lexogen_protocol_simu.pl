#!/usr/bin/perl -w
use strict;
use lib '/home/shichen.wang/perl5/lib/perl5';
use Bio::SeqFeature::Primer;
use Bio::DB::Fasta;
use Bio::Restriction::Enzyme;
use Bio::Restriction::EnzymeCollection;
use Bio::Restriction::Analysis;
use Getopt::Long;
use Parallel::ForkManager;


my ($fasta_file, $enz, $enz_seq, $starter, $stopper, $MIN_FRAG_LEN, $MAX_FRAG_LEN);
($MIN_FRAG_LEN, $MAX_FRAG_LEN) = (250, 600);

GetOptions ("fa=s"      => \$fasta_file, 
            "enz=s"     => \$enz,
            "enzseq=s"  => \$enz_seq,
            "starter=s" => \$starter,
            "stopper=s" => \$stopper,
            "minFragLen=i" =>\$MIN_FRAG_LEN,
            "maxFragLen=i" =>\$MAX_FRAG_LEN
            );

unless ($fasta_file and $starter and $stopper) {&help; exit}

my $gn = Bio::DB::Fasta->new($fasta_file);

if ($ENV{DEBUG}){
	my @ps = get_re_pos($gn, 1, "ATCG");
	print STDERR join("\n", @ps), "\n";
}

my @ids = $gn->ids();
my ($gn_total, $gn_target) = (0, 0);
foreach my $chr (@ids) {
	next if $chr =~ /\D/;
	&timestamp("Processing chromosome:", $chr);
	my @starter_pos = get_kmer_pos($gn, $chr, $starter);
	my @stopper_pos = get_kmer_pos($gn, $chr, $stopper);
	my @re_pos;
	if($enz or $enz_seq) {
		@re_pos = get_re_pos($gn, $chr, $enz, $enz_seq);
	}
	my $forward_count = count_fragments($starter_pos[0], $stopper_pos[0], [@re_pos]);
	my $reverse_count = count_fragments($starter_pos[1], $stopper_pos[1], [@re_pos]);
	my ($total, $target) = ($forward_count->[0] + $reverse_count->[0], $forward_count->[1] + $reverse_count->[1]);
	$gn_total += $total;
	$gn_target += $target;
	print STDERR join("\t", "chr".$chr, $total, $target, sprintf("%.2f", $target / $total)), "\n";
}
print join("\t", $starter, $stopper, $gn_total, $gn_target), "\n";




## subroutines
sub count_fragments {
	my ($s, $e, $re) = @_;
	my ($total, $target) = (0, 0);
	my $s_index = 0;
	my $e_index = 0;
	while ($s_index < (scalar @$s) and $e_index < (scalar @$e)) {
		if ($s->[$s_index] > $e->[$e_index]){
			$e_index++
		}
		else {
			if($s_index == (scalar @$s) - 1 or $s->[$s_index+1] > $e->[$e_index]) {
				my $frag_len = $e->[$e_index] - $s->[$s_index] + 1;
				$total ++;
				$target++ if $frag_len >= $MIN_FRAG_LEN and $frag_len <= $MAX_FRAG_LEN;
			}
			$s_index++;
		}
	}
	return [$total ,$target];
}

sub get_kmer_pos {
	my ($gn, $chr, $kmer) = @_;
	my $kmer_rc = revcomp($kmer);
	my @positions = ();
	# check plus strand
	my $fasta = $gn->get_Seq_by_id($chr)->seq;
	while($fasta =~ /$kmer/gi) {
		push @{$positions[0]}, pos($fasta)
	}
	# check minus strand
	while($fasta =~ /$kmer_rc/gi) {
		push @{$positions[1]}, pos($fasta)
	}	
	return @positions;
}


sub get_re_pos {
	my ($gn, $chr, $enz_name, $enz_seq) = @_;
	# create a re
	#                           1   2   3   4   5   6   7   8  ...
    #     N + N + N + N + N + G + A + C + T + G + G + N + N + N
    #... -5  -4  -3  -2  -1
    my $re;
    if ($enz_name){
    	my $default_collection = Bio::Restriction::EnzymeCollection->new();
    	$re = $default_collection->get_enzyme( $enz_name );
    }
    else{
		$re = Bio::Restriction::Enzyme->new(-enzyme => "FakeEnz", -seq=>$enz_seq, -cut=>length($enz_seq), -site=>$enz_seq);
    }
	my $gn_seq = $gn->get_Seq_by_id($chr);
	my $ra = Bio::Restriction::Analysis->new(-seq=>$gn_seq, -enzymes=>$re);
	my @positions = $ra->positions($re->name);
	return @positions
}

sub revcomp {
	my $seq = shift;
	$seq = uc($seq);
	$seq=~ tr/[ATGC]/[TACG]/;
	$seq = reverse $seq;
	return $seq;
}

sub help {
print qq(
This program trying to simualte the alternative RADseq protocol, proposed by Rick, Charlie and Lexogen.

5'------------------------------------------------------------------3'
          -------stopper                 starter -------
       | |                                              | |
       | |                                              | |
       | |                                              | |
       | |                                              | |
       | |                                              | |


Usage: 
perl $0
-fa          fasta_file
-enz         restriction enzyme name
-enzseq      if you don't have the enzyme name, use this option
-starter     starter sequence
-stopper     stopper sequence
-minFragLen  minimum length of targeted fragment, default: 250
-maxFragLen  maximum length of targeted fragment, default: 600

Note: if restriction enzymes were defined, it means the genome would be digested with restriction enzyme first.

);	 
}

sub timestamp {
	my $t = localtime(time);
	print STDERR $t, "\t", join(" ", @_), "\n";
}
