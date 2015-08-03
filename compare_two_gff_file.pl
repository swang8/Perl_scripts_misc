#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
# This script will read two specifed gff-like file (which is different with normal gff)
# and compare the exon structures in these two files.
perl $0
<gff3 file generated by script run_genewise_wrapper.pl>
<gff3 file generate by PASA pipeline>
<output file>
);
die $sUsage unless @ARGV >= 3;
my($wise_gff, $pasa_gff, $outfile) = @ARGV;

my %wise_str = read_wise_gff($wise_gff);
my %pasa_str = read_pasa_gff($pasa_gff);
my ($total, %comp_result) = compare_structure(\%wise_str, \%pasa_str);
output ($total, \%comp_result, $outfile);

# Subroutines

sub output
{
	# $return_hash{$id} = [$left_alt, $right_alt, $conserved, $hc_exon, $retained_intron, $join_exon, $splice_exon, $skip_exon];
	my($total, $hashref, $file) = @_;
	open (OUT, ">$file") or die "$!\n";
	my @record;
	my @names = qw(left_alt right_alt conserved hc_exon retained_intron join_exon splice_exon skip_exon);
	map{$record[$_] = 0}(0..$#names);
	print OUT 'ID',"\t", join("\t", @names),"\n";
	foreach my $id (keys %$hashref)
	{
		print OUT $id,"\t", join("\t", @{$hashref->{$id}}),"\n";
		my $num = scalar (@{$hashref->{$id}});
		foreach (0 .. $num-1)
		{
			$record[$_] ++ if $hashref->{$id}->[$_] > 0;
		}
	}
	close OUT;
	
	print 'Total',"\t", $total,"\n";
	foreach (0..$#names)
	{
		print $names[$_],"\t",$record[$_],"\n";
	}
}


sub read_wise_gff
{
	my $file = shift;
	my %return_hash;
	open (IN, $file) or die $!;
	my $score;
	my $genewise_cutoff = 35;
	while (<IN>)
	{
		next if /^\s+$/ or /^\W/;
		my @t = split /\t/, $_;
		if ($t[2] =~ /match/){$score = $t[5]}
		next unless $t[2] =~ /cds/i;
		next unless $score > $genewise_cutoff;
		push @{$return_hash{$t[0]}},[@t[3, 4]];		
	}
	close IN;
	map{ $return_hash{$_} = [ sort{$a->[0]<=>$b->[0]} @{$return_hash{$_}} ] }keys %return_hash;
	return %return_hash;
}

sub read_pasa_gff
{
	my $file = shift;
	my %return_hash;
	open (IN, $file) or die $!;
	while (<IN>)
	{
		next if /^\s+$/;
		my $id = $1 if /Target=(\S+)\s/;
		my @t = split /\t/, $_;
	#	print $id, "\t", join("\t", @t[3, 4]),"\n" if $id =~ /asmbl_1222/;
		push @{$return_hash{$id}},[@t[3, 4]];		
	}
	close IN;
	map{ $return_hash{$_} = [ sort{$a->[0]<=>$b->[0]} @{$return_hash{$_}} ] }keys %return_hash;
	return %return_hash;
}



sub compare_structure
{
	my ($wise_ref, $pasa_ref) = @_;
	my %return_hash;
	my($total_genes);
	foreach my $id (keys %$wise_ref)
	{
		$total_genes++;
		my($left_alt, $right_alt, $conserved, $hc_exon, $retained_intron, $join_exon, $splice_exon, $skip_exon) = (0,0,0,0,0,0,0,0);
		my ($wise_vec, $wise_max, $wise_total) = construct_vec($wise_ref->{$id});
		my ($pasa_vec, $pasa_max, $pasa_total) = construct_vec($pasa_ref->{$id});
		foreach (@{$wise_ref->{$id}})
		{
			my ($start, $end) = @$_;
		#	print STDERR '$start, $end ', $start, "\t", $end, "\n" if $id =~ /asmbl_1222/;
			my $covered_by_pasa = 0;
			foreach ($start..$end)
			{
				$covered_by_pasa++ if (vec($pasa_vec, $_,1) == 1);
				#print $_, "\t",  $covered_by_pasa,"\n" if (vec($pasa_vec, $_,1) == 1);
			}
		#	print '$covered_by_pasa ', $covered_by_pasa,"\n" if $id =~ /asmbl_1222/;
			#
			if ($covered_by_pasa >= ($end-$start+1)*0.9)
			{
				$hc_exon++ 
			}
			elsif ($covered_by_pasa > 5)
			{
				$retained_intron++ if (vec($pasa_vec, $start-1,1) == 1 or vec($pasa_vec, $end+1,1) == 1);
				$splice_exon++;
			}
			else
			{
				$skip_exon++
			}
			#
			foreach my $p_ref (@{$pasa_ref->{$id}})
			{
				$conserved++ if $p_ref->[0] == $start and $p_ref->[1] == $end;
				$left_alt ++ if $p_ref->[0] != $start and $p_ref->[1] == $end;
				$right_alt++ if $p_ref->[0] == $start and $p_ref->[1] != $end;
			}
		}
		#
		foreach my $i (0..( (scalar @{$wise_ref->{$id}})-2 ))
		{
			my ($t, $c) = (0, 0);
			foreach ($i .. $i+1)
			{
				my ($start, $end) = @{$wise_ref->{$id}->[$_]};
				$t += ($end-$start+1);
				map{$c++ if (vec($pasa_vec, $_,1) == 1)} ($start, $end);
			}
			$join_exon++ if $c >= $t*0.9;
		}
		
		foreach (@{$pasa_ref->{$id}})
		{
			my ($start, $end) = @$_;
	#		print STDERR '$start, $end ', $start, "\t", $end, "\n" if $id =~ /asmbl_1222/;
			my $covered_by_wise = 0;
			map{$covered_by_wise++ if (vec($wise_vec, $_,1) == 1)} ($start..$end);
			$retained_intron++ if $covered_by_wise <= ($end-$start+1)*0.9;
	#		print '$covered_by_wise ', $covered_by_wise,"\n" if $id =~ /asmbl_1222/;
		}
		$return_hash{$id} = [$left_alt, $right_alt, $conserved, $hc_exon, $retained_intron, $join_exon, $splice_exon, $skip_exon];
	}
	return ($total_genes, %return_hash);
}



sub construct_vec
{
	my $arrayref = shift;
	my $vec = '';
	my $max;
	my $total;
	my $debug =1 ;
	foreach (@$arrayref)
	{
		my @d = sort{$a<=>$b}@$_;
#		print '@d: ', join("\t", @d),"\n" if $debug; $debug=0;
		foreach ($d[0]..$d[1])
		{
			vec($vec,$_,1) = 0b1;
			$total++;
			$max = $_ unless defined $max;
			$max = $_ if $_ > $max;
			
		}
	}
	return ($vec, $max, $total);
}
