#!/usr/bin/perl -w
use strict;
use Parallel::ForkManager;

my $sUsage = "perl $0 <num_threads> <fastq>\n";
die $sUsage unless @ARGV == 2;
my($num_threads, $fastq) = @ARGV;

open (IN, "$fastq") or die "can't open file $fastq\n";

my $out_file = "mira_contigs.output";
open (my $out_fh, ">$out_file") or die $!;

my $count_mira = 0;
my @data;
my $line_counter = 0;
my $pre_id;
while(<IN>)
{
	next if /^\s+$/;
	chomp;
	my $line = $_;
	$line_counter++;
	#print STDERR 'scalar @data: ', scalar @data, "\n";
	if($line_counter % 4 == 1)
	{
		# @DJB775P1:264:D0M7EACXX:3:1107:7206:67178-1 BL:0 PH:0 CT:td-k45_contig_51016
		my $id = $1 if $line=~/(BL.*\d+)$/;
		$pre_id = $id unless defined $pre_id;
		#print STDERR $pre_id, "\t", $id, "\n";
		if($id eq $pre_id)
		{
			push @data, $line;
		}
		else
		{
			run_mira($pre_id, @data);
			$pre_id = $id;
			@data=();
			push @data, $line;
		}
	}
	else
	{
		push @data, $line;
	}	
	
	if(eof(IN))
	{
		 run_mira($pre_id, @data);
	}
}
close IN;


sub run_mira
{
	$count_mira++;
	print STDERR "Runnig mira times: ", $count_mira, "\n";
	my ($id, @data) = @_;
	my $mira_bin = "/home/DNA/Tools/mira_3.2.1_prod_linux-gnu_x86_64_static/bin/mira ";
	my $tmp_fasta_file = "data.tmp.fasta";
	my $tmp_qual_file = "data.tmp.fasta.qual";
	generate_files($tmp_fasta_file, $tmp_qual_file, @data);
	
	my $cmd = $mira_bin . "--project=mira_tmp --job=denovo,solexa,est --fasta=" . $tmp_fasta_file;
	print STDERR $cmd, "\n";
	eval{ system($cmd)}; return if $@;
	my $mira_contig = "mira_tmp_assembly/mira_tmp_d_results/mira_tmp_out.padded.fasta";
    return unless -e $mira_contig;
	my $cap3 = "/home/DNA/Tools/CAP3/cap3 ";
	die if system($cap3. $mira_contig);
	
	my @cap_outputs = map{$mira_contig.$_}(".cap.contigs", ".cap.singlets");
	
	processing_fasta_file($id, @cap_outputs);
}

sub generate_files
{
	my ($fasta, $qual, @data) = @_;
	open(F, ">$fasta") or die;
	open(Q, ">$qual") or die;
	foreach my $ind(0..$#data)
	{
		if($ind % 4 == 0)
		{
			$data[$ind]=~s/\@/>/;
			print F $data[$ind], "\n";
			print Q $data[$ind], "\n";
		}
		if($ind % 4 ==1)
		{
			print F $data[$ind], "\n";
		}
		if($ind % 4 == 3)
		{
			my @s = split //, $data[$ind];
			my @q=map{ord($_)-33}@s;
			print Q join(" ", @q), "\n";
		}		
	}
	close F;
	close Q;
}

sub processing_fasta_file
{
	my $pre_id = shift;
	my @files = @_;
	my %hash;
	my $count = 0;
	foreach my $f (@files)
	{
		open (I, $f) or die;
		my $id;
		while(<I>)
		{
			chomp;
			if(/>/){$count++; $id="C".$count; next}
			$hash{$id} .=$_;
		}
		close I;
	}
	
	foreach (keys %hash)
	{
		print {$out_fh} ">", $_, " ", $pre_id, "\n", $hash{$_}, "\n";
	}
}

