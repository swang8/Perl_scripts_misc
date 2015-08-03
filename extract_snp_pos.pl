#!/usr/bin/perl -w
use strict;

# take the flanking sequences of SNPs blat against flow sorted sequences;
# figure out the chr and positions that SNP located;

my @input_files = @ARGV;

my %blat_results;
foreach my $in (@input_files)
{
	open (IN, $in) or die $!;
	while (<IN>)
	{
		# wsnp_Ex_c14832_22953585:100:A:C   1BS     98.92   93      1       0       1       93      160850162       160850254       8.4e-46 181.0
		# wsnp_Ex_c14832_22953585:100:A:C   1BS     100.00  82      0       0       102     183     160850914       160850995       1.8e-39 160.0
		my @data = split /\s+/, $_;
		my $snp_pos = $1 if $data[0]=~/:(\d+):/;
		next if $data[6] > $snp_pos+1 or $data[7] <= $snp_pos;
		my $new_pos = $data[8] + ($data[8] < $data[9]?1:-1) * ($snp_pos - $data[6] + 1);
		
		if(exists $blat_results{$data[0]}{$data[1]})
		{
			next if $blat_results{$data[0]}{$data[1]}->[0] >= $data[2];
		}
		
		$blat_results{$data[0]}{$data[1]} = [$data[2], $new_pos];		
	}
	close IN;
}

##

foreach my $id (keys %blat_results)
{
	my @chrs = keys %{$blat_results{$id}};
	next unless @chrs >= 3;
	
	my @perfect;
	my @nonperf;
	
	foreach (@chrs)
	{
		if($blat_results{$id}{$_}->[0] == 100){push @perfect, $_}
		else{push @nonperf, $_}
	}
	
	my $count_p = count_unique(@perfect);
	my $count_nonp = count_unique(@nonperf);
	
	my @alleles = $id=~/:(\S):(\S)$/;
	if($count_p == 1 and $count_nonp == 2)
	{
		
 		foreach (@perfect){print $id, "\t", $_, "\t", $blat_results{$id}{$_}->[1], "\t", join("\t", @alleles), "\n"}
	}
	
	if($count_p == 2 and $count_nonp == 1)
	{
 		foreach (@nonperf){print $id, "\t", $_, "\t", $blat_results{$id}{$_}->[1], "\t", join("\t",  reverse @alleles), "\n"}
	}
	
}


sub count_unique
{
	my @arr = @_;
	my $count = 0;
	my %h;
	%h = map {($1, 1) if /^(\S{2})/} @arr;
	return scalar (keys %h);
}