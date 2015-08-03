#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;
use Bio::SearchIO;

my $sUsage = <<END;
Usage:
perl $0
<ortholog gene pairs list file, 3B_S293	3A_S1531>
<3B BAC sequences in fasta>
<3B transcript isoform annotation file generated by PASA, gff3 format>
<3A contig/scaffold sequences in fasta>
<3A transcript isoform annotation file generated by PASA, gff3 format>
<output file>
END

die $sUsage unless @ARGV >= 6;

my ($ortho_file, $B_bac_file, $B_iso_gff, $A_scaffold_file, $A_iso_gff, $outfile) = @ARGV;
open (OUT, ">$outfile") or die;

my @ortho_A_B = read_ortho_file($ortho_file);
my $gn_3A = Bio::DB::Fasta->new($A_scaffold_file);
my $gn_3B = Bio::DB::Fasta->new($B_bac_file);


my ($B_gene_asmbl, $B_isoform_struc, $B_isoform_struc_transformed, $B_asmbl_strand, $B_asmbl_bac) = read_gff($B_iso_gff);
my ($A_gene_asmbl, $A_isoform_struc, $A_isoform_struc_transformed, $A_asmbl_strand, $A_asmbl_scaffold) = read_gff($A_iso_gff);

my @as_events = qw(ADE AAE CE RI SI SE RE);

foreach my $ortho (@ortho_A_B)
{	
	my $b_gene = $1 if $ortho =~ /3B_(S\d+)/;
	my $b_asmbl = $1 if $ortho =~  /3B_(asmbl_\d+)/;
	my $a_gene = $1 if $ortho =~  /3A_(S\d+)/;
	my $a_asmbl = $1 if $ortho =~  /3A_(asmbl_\d+)/;
	
	print STDERR "Getting sequences ... \n";
	print STDERR "*", $A_scaffold_file, "\n", $B_bac_file, "\n";
	my $b_asmbl_seq = get_seq($gn_3B, $b_asmbl, $B_asmbl_strand->{$b_asmbl}, $B_asmbl_bac->{$b_asmbl}, $B_isoform_struc);
	my $a_asmbl_seq = get_seq($gn_3A, $a_asmbl, $A_asmbl_strand->{$a_asmbl}, $A_asmbl_scaffold->{$a_asmbl}, $A_isoform_struc);
	
	print STDERR $b_asmbl_seq, "\n", $a_asmbl_seq, "\n";
	
	my $b_iso_num = scalar @{$B_gene_asmbl->{$b_gene}};
	my $a_iso_num = scalar @{$A_gene_asmbl->{$a_gene}};
	#print STDERR $ortho, "\t", $b_iso_num, "\t", $a_iso_num, "\n";
	my %b_as_events = compare_isoforms($b_gene, $B_gene_asmbl, $B_isoform_struc_transformed);
	my %a_as_events = compare_isoforms($a_gene, $A_gene_asmbl, $A_isoform_struc_transformed);
	#print STDERR "Finished comparing isoforms ...\n";
	
	# check align positions	
	&run_blast2seq($b_asmbl_seq, $a_asmbl_seq, $b_asmbl."_3B", $a_asmbl."_3A");
	my ($b_aln_start, $b_aln_end, $b_strand, $a_aln_start, $a_aln_end, $a_strand) = parse_blast2seq();
	print STDERR 'S390 ', join("*", ($b_aln_start, $b_aln_end, $b_strand, $a_aln_start, $a_aln_end, $a_strand)), "\n" if $b_gene eq "S390";
	
	# check if AS events were in the same exons or not
	my %exon_count;
	my $debug = 1 if $b_gene eq "S390";
	foreach my $event (@as_events)
	{
		if($b_iso_num == 1 and $a_iso_num == 1)
		{
			$exon_count{$ortho}{$event} = [0, 0, 0];
			next;
		}
		#print STDERR "Processing event $event ...\n";
		my @b_exons = exists $b_as_events{$event}?@{$b_as_events{$event}}:();
		@b_exons = @{$b_as_events{'ONE'}} if $b_iso_num == 1;
		@b_exons = merge_exons(@b_exons);
		my @b_exons_orig = @b_exons;
		print STDERR join("**", @b_exons), "\n" if $debug;
		@b_exons = transform_coordinate($b_asmbl, $B_isoform_struc_transformed, $B_asmbl_strand, $b_aln_start, $b_aln_end, $b_strand, @b_exons) if @b_exons;
		print STDERR join("**", @b_exons), "\n" if $debug; #$debug=0;
		my @a_exons = exists $a_as_events{$event}?@{$a_as_events{$event}}:();
		@a_exons = @{$a_as_events{'ONE'}} if $a_iso_num == 1;
		@a_exons = merge_exons(@a_exons);
		my @a_exons_orig = @a_exons;
		print STDERR join("***", @a_exons), "\n" if $debug;
		@a_exons = transform_coordinate($a_asmbl, $A_isoform_struc_transformed, $A_asmbl_strand, $a_aln_start, $a_aln_end, $a_strand, @a_exons) if @a_exons;
		print STDERR join("***", @a_exons), "\n" if $debug;	
		my @overlap_exons = check_overlapping(\@b_exons, \@a_exons);
		$exon_count{$ortho}{$event} = [scalar @b_exons, scalar @a_exons, scalar @overlap_exons];
		$exon_count{$ortho}{$event} = [0, scalar @a_exons, scalar @overlap_exons] if $b_iso_num == 1;
		$exon_count{$ortho}{$event} = [scalar @b_exons, 0, scalar @overlap_exons] if $a_iso_num == 1;
		
		print_sequences(\@overlap_exons, \@b_exons, $b_asmbl_seq);
		
		#print STDERR 'S390 ', $event, "\t", join("\t", (scalar @b_exons, scalar @a_exons, scalar @overlap_exons)), "\n" if $b_gene eq "S390";
	}
	
	#exit if $a_gene eq "S3033";
	#exit if $b_gene eq "S390";
	
	# output
	print OUT $ortho, "\t", $b_iso_num, "\t", $a_iso_num;
	foreach (@as_events)
	{
		print OUT "\t"x4, join("\t", (@{$exon_count{$ortho}{$_}}))
	}
	print OUT "\n";
}

close OUT;


# Subroutines$seq .= $gn_obj->seq(chr, $start => $end);
sub print_sequences
{
	my ($overlap_exons, $b_exons, $seq) = @_;
	foreach (@$overlap_exons)
	{
		my ($start, $end) = split /_/, $_;
		my $seq = substr($seq, $start-1, $end-$start+1);
		print ">shared_seq\n", $seq, "\n" if (length $seq) >=30;
	}
	
	foreach (@$b_exons)
	{
		my @over = check_overlapping([$_], $overlap_exons);
		next if @over;
		my ($start, $end) = split /_/, $_;
		my $seq = substr($seq, $start-1, $end-$start+1);
		print ">unique_seq\n", $seq, "\n" if (length $seq) >=30;
	}
}



sub get_seq
{
	# $gn_3B, $b_asmbl, $B_asmbl_strand->{$b_gene}, $B_asmbl_bac->{$b_gene}, $B_isoform_struc
	my ($gn_obj, $asmbl, $strand, $chr, $struc_ref) = @_;
	print STDERR 'chr: ', $chr, "\n";
	my @struc = @{$struc_ref->{$asmbl}};
	my $seq = "";
	if($strand eq '+')
	{
		@struc = sort {$a->[0] <=> $b->[0]} @struc;
		foreach (@struc)
		{
			my ($start, $end) = @$_;
			$seq .= $gn_obj->seq($chr, $start => $end);
		}
	}
	else
	{
		@struc = sort {$b->[0] <=> $a->[0]} @struc;
		foreach (@struc)
		{
			my ($start, $end) = @$_;
			$seq .= $gn_obj->seq($chr, $end => $start);			
		}
	}
	
	return $seq;
}



sub merge_exons
{
	my @exons = @_;
	my %rm_index;
	foreach my $m (0..$#exons)
	{
		my ($m_s, $m_e) = split /_/, $exons[$m];
		
		foreach my $j(0..$#exons)
		{
			next if $j == $m;
			next if exists $rm_index{$j};
			my ($j_s, $j_e) = split /_/, $exons[$j];
			if($m_s == $j_s)
			{
				$rm_index{$j} =1 if $m_e >= $j_e;
				$rm_index{$m} =1 if $m_e <= $j_e;
			}
			
			if($m_e == $j_e)
			{
				$rm_index{$j} = 1 if $m_s <= $j_s;
				$rm_index{$m} = 1 if $m_s >= $j_s;
			}			
		}		
	}
	my @return;
	
	foreach (0..$#exons)
	{
		push @return, $exons[$_] unless exists $rm_index{$_};
	}
	return @return;
}
sub check_overlapping
{
	my @arrref = @_;
	#@arrref = reverse @arrref if (@{$arrref[0]} > @{$arrref[1]});
	my ($b_ref, $a_ref) = @arrref;
	
	my @return;
	
	foreach (@$b_ref)
	{
		my ($start, $end) = split /_/, $_;
		my $overlap = 0;
		foreach (@$a_ref)
		{
			my @pos = split /_/, $_;
			if( ($pos[0]>=$start and $pos[0] <= $end) or ($start >= $pos[0] and $start <= $pos[1]) )
			{
				$overlap = 1;
				last;
			}
		}
		push @return, $_ if $overlap;
	}
	
	return @return;
}


sub compare_isoforms
{
	# $b_gene, $B_gene_asmbl, $B_isoform_struc
	my ($gene, $gene_asmbl, $iso_struc_ref) = @_;
	my @iso_struc;
	foreach (@{$gene_asmbl->{$gene}})
	{
		push @iso_struc, $iso_struc_ref->{$_}
	}
	
	my %return;
	
	foreach my $m (0..$#iso_struc)
	{
		my $max_length_asmbl = 0;
		my ($isoa_vec, $max_lena) = construct_vec($iso_struc[$m]);
		$max_length_asmbl = $max_lena if $max_lena > $max_length_asmbl;
		
		if(@iso_struc == 1)
		{
			my @coding_segments = calculate_coding_segment($isoa_vec, $isoa_vec, $max_length_asmbl);
			
			foreach  my $index (1..@coding_segments-1)
			{
				my $segment = $coding_segments[$index];
				my $status = $segment->[2];
				next unless $status == 11;
				push @{$return{'ONE'}}, join("_", ($coding_segments[$index]->[0],  $coding_segments[$index]->[1]));		
			}
			
			last;
		}
		
		foreach my $j (0..$#iso_struc)
		{
			next if $j == $m;
			my ($isob_vec, $max_lenb) = construct_vec($iso_struc[$j]);
			$max_length_asmbl = $max_lenb if $max_lenb > $max_length_asmbl;
			my @coding_segments = calculate_coding_segment($isoa_vec, $isob_vec, $max_length_asmbl);
						
			my ($ade, $aae, $ri, $si, $se, $re, $ce) = (0,0,0,0,0,0,0);
			my $first_align;
			my $last_align;
			foreach  my $index (1..$#coding_segments-1)
			{
				my $segment = $coding_segments[$index];
				my $status = $segment->[2];
				$first_align = $index if $status == 11 and not defined $first_align;
				$last_align = $index if $status == 11;
			}
			foreach  my $index ($first_align-1..$last_align+1)
			{
				my $segment = $coding_segments[$index];
				my $status = $segment->[2];
				next if $status == 0;
				
				if ($status == 11)
				{
					if ($coding_segments[$index-1]->[2] == 0 and $coding_segments[$index+1]->[2] == 0) # ce
					{
						$ce++;
						push @{$return{'CE'}}, join("_", ($coding_segments[$index]->[0],  $coding_segments[$index]->[1]));
					}
					next;
				}
				
				if ($coding_segments[$index-1]->[2] == 11 and $coding_segments[$index+1]->[2] == 0) # ade
				{
					$ade++ ;
					push @{$return{'ADE'}}, join("_", ($coding_segments[$index-1]->[0],  $coding_segments[$index]->[1]));
				}
				
				if($coding_segments[$index-1]->[2] == 00 and $coding_segments[$index+1]->[2] == 11) # aae
				{
					$aae++;
					push @{$return{'AAE'}}, join("_", ($coding_segments[$index]->[0],  $coding_segments[$index+1]->[1]));
				}
				
				if ($coding_segments[$index-1]->[2] == 11 and $coding_segments[$index+1]->[2] == 11 and $status == 10) #ru
				{
					$ri++;
					push @{$return{'RI'}}, join("_", ($coding_segments[$index-1]->[0],  $coding_segments[$index+1]->[1]));;
				}
				
				if ($coding_segments[$index-1]->[2] == 11 and $coding_segments[$index+1]->[2] == 11 and $status == 1) #si
				{
					$si++;
					push @{$return{'SI'}}, join("_", ($coding_segments[$index-1]->[0],  $coding_segments[$index+1]->[1]));
				}
				
				if ($coding_segments[$index-1]->[2] == 0 and $coding_segments[$index+1]->[2] == 0 and $status == 1) #se
				{
					$se++;
					push @{$return{'SE'}}, join("_",($coding_segments[$index]->[0],  $coding_segments[$index]->[1]));
					#print STDERR join("_",($coding_segments[$index]->[0],  $coding_segments[$index]->[1])), "!!!\n" if $gene eq 'S134';
				}
				
				if ($coding_segments[$index-1]->[2] == 0 and $coding_segments[$index+1]->[2] == 0 and $status == 10) #re
				{
					$re++;
					push @{$return{'RE'}}, join("_", ($coding_segments[$index]->[0],  $coding_segments[$index]->[1]));
				}
				
			}
		}
	}

	foreach my $event (keys %return)
	{
	#	print STDERR 'Event: ', $event, "\n";
		my $arrayref = $return{$event};
		unless (ref($arrayref) eq 'ARRAY')
		{
			print STDERR $_, "!\t", $arrayref, "!\n";
			die;
		}
		#print STDERR $arrayref, "\n";
		my @unique_regions = unique(@$arrayref);
		#print STDERR join("*\t", @unique_regions), "*\n";
		$return{$event} = [@unique_regions];
	}

	return %return;
}


sub transform_coordinate
{
	# $b_asmbl, $B_isoform_struc, $b_aln_start, $b_aln_end, $b_strand, @b_exons
	my ($asmbl, $asmbl_struc_ref, $asmbl_strand_ref, $aln_start, $aln_end, $aln_strand, @exons) = @_;

	my @pos;
	foreach (@{$asmbl_struc_ref->{$asmbl}})
	{
		my ($start, $end) = @$_;
		push @pos, ($start, $end);
	}
	print STDERR $asmbl_strand_ref->{$asmbl}, "\n" if $asmbl eq 'asmbl_1593';
	print STDERR join("!", @pos), "\n" if $asmbl eq 'asmbl_1593';
	@pos = sort {$a <=> $b} @pos;
	print STDERR join("!", @pos), "\n" if $asmbl eq 'asmbl_1593';
	
	my @asmbl_pos_formated;
	if($asmbl_strand_ref->{$asmbl} eq '+')
	{
		my $pre_len = 0;
		foreach (@{$asmbl_struc_ref->{$asmbl}})
		{
			my ($start, $end) = @$_;
			push @asmbl_pos_formated, [$pre_len+1, $pre_len+1+$end-$start];
			print STDERR join("*", ($pre_len+1, $pre_len+1+$end-$start)), "\t" if $asmbl eq 'asmbl_1593';
			$pre_len += ($end-$start+1);
		}
		print STDERR "\n" if $asmbl eq 'asmbl_1593';
	}
	else
	{
		my $pre_len = 0;
		foreach (reverse @{$asmbl_struc_ref->{$asmbl}})
		{
			my ($start, $end) = @$_;
			push @asmbl_pos_formated, [$pre_len+1, $pre_len+1+$end-$start];
			print STDERR join("*", ($pre_len+1, $pre_len+1+$end-$start)), "\t" if $asmbl eq 'asmbl_1593';
			$pre_len += ($end-$start+1);			
		}
		print STDERR "\n" if $asmbl eq 'asmbl_1593';
	}
			
	my @new_exon_pos;	
	foreach (sort{(split /_/, $a)[0] <=> (split /_/, $b)[0]} @exons)
	{
		my ($start, $end) = split /_/, $_;
		print STDERR '$start, $end: ', $start,"\t", $end, "\n" if $asmbl eq 'asmbl_1593';
		foreach my $index (0 .. scalar @{$asmbl_struc_ref->{$asmbl}}-1)
		{
			my ($s, $e) = @{$asmbl_struc_ref->{$asmbl}[$index]};
			print STDERR '($s, $e): ', $s,"\t", $e, "\n" if $asmbl eq 'asmbl_1593';
			if( ($start >= $s and $start <= $e) or ($s >= $start and $s <= $end) )
			{
				push @new_exon_pos, join("_", @{$asmbl_pos_formated[$index]});
				last;
			}			
		}
	}	
	print STDERR join("!", @new_exon_pos), "\n" if $asmbl eq 'asmbl_1593';
	
	#transform coordinates according to alignment
	# $aln_start, $aln_end, $aln_strand	
	my @transformed_exon_pos;	
	if($aln_strand == 1) # plus
	{
		foreach (@new_exon_pos)
		{
			my ($start, $end) = split /_/, $_;
			next if $start > $aln_end;
			next if $end < $aln_start;
			my $new_start = $start - $aln_start < 0? 0: $start - $aln_start + 1;
			my $new_end = $end - $aln_start < 0? 0: $end - $aln_start + 1;
			next if $new_start == $new_end;
			$new_start = 1 if($new_start == 0);
			push @transformed_exon_pos, join("_", ($new_start, $new_end));
		}
	}
	elsif($aln_strand == -1)
	{
		foreach (@new_exon_pos)
		{
			my ($start, $end) = split /_/, $_;
			next if $start > $aln_end;
			next if $end < $aln_start;
			my $new_start = $aln_end - $start < 0? 0: $aln_end-$start + 1;
			my $new_end = $aln_end- $end < 0? 0: $aln_end-$end + 1;
			next if $new_start == $new_end;
			$new_end = 1 if($new_end == 0);
			push @transformed_exon_pos, join("_", reverse($new_start, $new_end));
		}		
	}
	
	return @transformed_exon_pos;
}


sub parse_blast2seq
{
	my $searchio = Bio::SearchIO->new(-format => 'blast', -file => "blastn2seq.out", -report_type => 'blastn');
	while (my $result = $searchio->next_result())
	{
		#last unless defined $result;
		my $hit = $result->next_hit;
		#last unless defined $hit;
		while (my $hsp = $hit->next_hsp)
		{
			my $query_string = $hsp->query_string;
			my $query_start = $hsp->start('query');
			my $query_end = $hsp->end('query');
			my $query_strand = $hsp->strand('query');
			#my $query_string_formatted = format_sequence($query_string, $query_start, $B_gene_struc->{$b_gene});
			
			my $hit_string = $hsp->hit_string;
			my $hit_start = $hsp->start('hit');
			my $hit_end = $hsp->end('hit');
			my $hit_strand = $hsp->strand('hit');
			#my $hit_string_formatted = format_sequence($hit_string, $hit_start, $A_gene_struc->{$a_gene});
			return($query_start, $query_end, $query_strand, $hit_start, $hit_end, $hit_strand);	
			last;
		}		
	}	
}

sub run_blast2seq
{
	my ($b_gene_seq, $a_gene_seq, @out) = @_;
	open (Q, ">query") or die;
	print Q ">$out[0]\n", $b_gene_seq, "\n";
	close Q;
	
	open (S, ">subject") or die;
	print S ">$out[1]\n", $a_gene_seq, "\n";
	close S;
	
	my $blast_cmd = "bl2seq -i query -j subject -p blastn -o blastn2seq.out";
	system($blast_cmd);
	#print STDERR "Finish bl2seq ...\n";	
}



sub read_ortho_file
{
	my $file = shift;
	open (IN, $file) or die;
	
	my @return;
	while (<IN>)
	{
#	3B_asmbl_68     3A_asmbl_4089   3B_S61  3A_S3554
#	3B_asmbl_9      3A_asmbl_2942   3B_S8   3A_S2639
	
		chomp; next if /^\s+$/;

		push @return, $_;
	}
	close IN;
	
	return @return;
}


sub read_gff
{
	my $iso_gff = shift;
	open (ISO, $iso_gff) or die "Error opening file $iso_gff\n";
	my %gene_asmbl;
	my %asmbl_struc;
	my %asmbl_strand;
	my %asmbl_chr;
	while(<ISO>)
	{
		chomp; 
		next unless /\S/;
		# gi|300681572|emb|FN645450.1|	PASA	cDNA_match	16861	17032	.	+	.	ID=S319-asmbl_397; Target=asmbl_397 1 172 +
		# gi|300681572|emb|FN645450.1|	PASA	cDNA_match	17453	17519	.	+	.	ID=S319-asmbl_397; Target=asmbl_397 173 239 +
		# gi|300681572|emb|FN645450.1|	PASA	cDNA_match	17597	17670	.	+	.	ID=S319-asmbl_397; Target=asmbl_397 240 313 +
		my $gene_id = $1 if /ID=(S\d+)\-/;
		my $asmbl_id = $1 if /(asmbl_\d+)/;
		my @t = split /\s+/, $_;
		push @{$gene_asmbl{$gene_id}}, $asmbl_id;
		push @{$asmbl_struc{$asmbl_id}}, [ @t[3, 4] ];
		$asmbl_strand{$asmbl_id} = $t[6];
		$asmbl_chr{$asmbl_id} = "$t[0]";
	}
	close ISO;
	map{$gene_asmbl{$_} = [unique(@{$gene_asmbl{$_}})]} keys %gene_asmbl;

	my %asmbl_struc_transformed;
	my $debug = 1;
	foreach my $gene (keys %gene_asmbl)
	{
		my @all_exons;
		my @asmblies = @{$gene_asmbl{$gene}};
		print join("***", @asmblies), "\n" if $gene eq 'S134';
		foreach (@asmblies)
		{
			
			foreach (@{$asmbl_struc{$_}})
			{
				push @all_exons, @$_;
			}
		}
		@all_exons = sort {$a <=> $b} @all_exons;		
	
		foreach my $asmbl (@asmblies)
		{
			#print STDERR "***", $asmbl, "\n" if $gene eq 'S134';
			my @array = @{$asmbl_struc{$asmbl}};
			my @new_array;
			foreach (@array)
			{
				my ($start, $end) = @$_;
				#print STDERR "S134 $asmbl  $start $end\n" if $gene eq 'S134';
				$start = $start - $all_exons[0]+1;
				$end = $end - $all_exons[0] + 1;
				push @new_array, [$start, $end];
			}
			$asmbl_struc_transformed{$asmbl} = [@new_array];
		}		
	}

		
	return (\%gene_asmbl, \%asmbl_struc, \%asmbl_struc_transformed, \%asmbl_strand, \%asmbl_chr);
}


sub unique
{
	my %hash = map {$_, 1} @_;
	return keys %hash;
}


sub calculate_coding_segment
{
	my ($wise_vec, $pasa_vec, $max)= @_;
	
	my @coding_segs;
	my ($seg_start, $seg_end) = (0, 0);
	my $pre_status = 0;
	my $current_status;
	push @coding_segs, [0,0,0];
	#print STDERR "length: ", $max, "\n";
	foreach my $index ( 0..$max)
	{
		#print STDERR 'Index: ', $index, "\n";
		my $w = vec($wise_vec, $index,1);
		$w = 0 unless defined $w;
		my $p =  vec($pasa_vec, $index,1);
		$p = 0 unless defined $p;
		$current_status = $w*10+$p;
		$pre_status = $current_status if $index==0;
		if ($current_status == $pre_status)
		{
			if ($index == ($max))
			{
				push @coding_segs, [$seg_start, $max, $pre_status]
			}
			next;
		}
		$seg_end = $index - 1;
		push @coding_segs, [$seg_start, $seg_end, $pre_status];
		#print STDERR "Seg: ", $seg_start, "\t", $seg_end, "\t", $pre_status, "\n";
		$seg_start = $index;
		$pre_status = $current_status;		
	}
	push @coding_segs, [0,0,0];
	return (@coding_segs);
}

sub construct_vec
{
	my $arrayref = shift;
	my $length = shift;
	#my $flag= shift;
	my $vec = '';
	my $max;
	my $total;
	my $debug =1 ;
	my @array = @$arrayref;
	#if($flag){shift @array; pop @array} # remove terminal exons SW 10.06.2011
	foreach (@array)
	{
		my @d = sort{$a<=>$b}@$_;
		#print STDERR '@d ', join(",", @d), "\n";
#		print '@d: ', join("\t", @d),"\n" if $debug; $debug=0;
		foreach ($d[0]..$d[1])
		{
			vec($vec,$_,1) = 0b1;
		#	$total++;
			$max = $_ unless defined $max;
			$max = $_ if $_ > $max;
			
		}
	}
	return ($vec, $max);
}
