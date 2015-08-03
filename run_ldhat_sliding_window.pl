#!/usr/bin/perl -w
use strict;
use Parallel::ForkManager;

my $sUsage = qq(
*******************************************************************
perl $0 
  <SNP_genotyping_addPhysicalDist_sorted.csv>
  <window size, in Kb>
  <step size, in Kb>
  <output file>
*******************************************************************
);
die $sUsage unless @ARGV;
my ($genotype_file, $win_size, $step_size, $output) = @ARGV;
my ($genotypes_href, $dist_href)  = read_genotype_file($genotype_file);
open (my $OUT, ">$output") or die $!;
print $OUT "Chr\tStart_pos\tNum_SNP\taverage_PWD\twatterson_theta\ttajimaD\tfuliD\n";

my $convert_bin = "/home/DNA/Tools/ldhat/convert ";
my $tmp_dir = "tmp_ldhat";
mkdir($tmp_dir) unless -d $tmp_dir;

foreach my $chr (sort {$a cmp $b} keys %$genotypes_href)
{
	time_stamp("Processing chromosome ", $chr);
	my @dist = @{$dist_href->{$chr}};
	print STDERR $chr, "\t", $dist[0], "->", $dist[-1], "\n";
	my $num_accessions = scalar @{$genotypes_href->{$chr}};
	my @windows = generate_windows(@dist[0,-1], $win_size*1000, $step_size*1000);
	print STDERR "\@windows : ", scalar @windows, "\n";
	foreach (0 .. $#windows)
	{
		my ($start, $end) = @{$windows[$_]};
		print STDERR "\t", $chr, "\t$_\t", $start, "->", $end, "\n";
		my @ind = grep{$dist[$_] >= $start and $dist[$_] <= $end}0..$#dist;
		if(@ind == 0) # no SNPs
		{
			print $OUT join("\t", ($chr, $start, 0, 0, 0, 0, 0)), "\n"; 
			next;
		}
		
		# run ldhat
		my $pre_fix = "t";
		$pre_fix = $chr . "_win".$_;
		#print $pre_fix , "\n";
		my $sites_file = $tmp_dir ."/$pre_fix".".sites";
		my $loci_file = $tmp_dir . "/$pre_fix".".loci";
		my $ldhat_out = $tmp_dir . "/$pre_fix".".convert";
	
		open (S, ">$sites_file") or die "$!";
		print S $num_accessions, " ", scalar @ind, " 2", "\n";
		foreach my $index (1..$num_accessions)
		{
			print S ">acc_", $index, "\n";
			my $genotype = substr($genotypes_href->{$chr}[$index-1], $ind[0], ($ind[-1] - $ind[0] + 1));
			print S $genotype, "\n";
		}
		close S;
		
		open (L, ">$loci_file") or die "$!";
		print L scalar @ind, "\t", ($dist[$ind[-1]] - $dist[$ind[0]])/1000, "\t", "L", "\n";
		my @loci = map {$_/1000} @dist[@ind];
		print L join("\n", @loci), "\n";
		close L;
		
		my $cmd = $convert_bin . "-seq $sites_file ". "-loc $loci_file " .">$ldhat_out";	
		
		system($cmd);
		
		#parse_convert_output
		open (my $IN, $ldhat_out) or die;
		my $flag = 0;
		my ($average_PWD, $watterson_theta, $tajimaD, $fuliD, $var_PWD) = ("NA", "NA", "NA", "NA", "NA");
		while(<$IN>)
		{
				$flag = 1 if /Summary of output data/;
				next unless $flag;
				next if /^\s+$/;
				$average_PWD = $1 if /Average.*=\s+(\S+)$/;
				$watterson_theta = $1 if /Watterson.*=\s+(\S+)$/;
				$tajimaD = $1 if /Tajima.*=\s+(\S+)$/;
				$fuliD = $1 if /Fu.*=\s+(\S+)$/;
				#$var_PWD = $1 if /Variance.*=\s+(\S+)$/;
		}
		print $OUT join("\t",($chr, $start, scalar @ind, $average_PWD, $watterson_theta, $tajimaD, $fuliD)), "\n";
		close $IN;		
	}
}

# Subroutines
sub generate_windows
{
	my ($start, $max, $win_size, $step_size) = @_;
	my $num_wins = int(($max - $start+1) / $step_size);
	$num_wins ++ if (($max - $start+1)%$step_size);
	print STDERR '$start, $max, $win_size, $step_size ', join("\t", ($start, $max, $win_size, $step_size)), "\n";
	print STDERR "\$num_wins: ", $num_wins, "\n";
	my @return;
	map{
		push @return, [($start + ($_-1)*$step_size), ($start + ($_-1)*$step_size + $win_size)>$max?$max:($start + ($_-1)*$step_size + $win_size) ] 
	}1..$num_wins;
	return @return;
}


sub time_stamp
{
	my $str = join(" ", @_);
	my $t = localtime();
	print $t, "\t", $str, "\n";
}

sub read_genotype_file
{
	my $file = shift;
	my %genotypes;
	my %dist;
	open (IN, $file) or die $!;
	while (<IN>)
	{
		# 3977290_1al:2245      703881  G       G       G       G       G       G       G       G       G 
		chomp;
		next unless /\S/;
		my @t=split /\t/,$_;
		my $chr = $1 if $t[0] =~ /_(\S+):/;
		if(exists $dist{$chr}){$t[1] = $dist{$chr}->[-1]+10 if $dist{$chr}->[-1] >= $t[1]}
		push @{$dist{$chr}}, $t[1];
		my @geno = map { /NA/?"?":$_ } @t[2..$#t];
		$genotypes{$chr} = [] unless exists $genotypes{$chr};
		map { $genotypes{$chr}[$_] .= $geno[$_] } 0..$#geno;
	}
	close IN;
	
	return (\%genotypes, \%dist);
}