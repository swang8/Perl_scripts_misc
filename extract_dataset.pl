#!/usr/bin/perl -w
use strict;

my $sUsage = qq(
perl $0 
<min4_snps_svm_features>
<min4_snps_svm_ids>
<min4_2_2.snps>
<output file>
);
die $sUsage unless @ARGV >= 4;
my($feature_file, $id_file, $info_file, $out_file) = @ARGV;

my %ids = read_id_file($id_file);
my %info = read_snp_file($info_file, \%ids);
get_data($feature_file, \%info, $out_file);

# 
sub read_id_file
{
	my $file = shift;
	open (IN, "$file") or die "can't open file $file\n";
	my $count = 0;
	my %return;
	my $debug = 1;
	while(<IN>)
	{
		next if /^\s+$/;
		$count++;
		chomp;
		my @t=split/\t/,$_;
		my $id = join(":", @t[0,1]);
		print STDERR 'ID: ', $id,"\t", $count,"\n" if $debug; $debug=0;
		print STDERR $count,"\n" if $id eq 'Kukri_mira1_rep_c83369:352';
		$return{$id} = $count;
	}
	close IN;
	return %return;
}


sub read_snp_file
{
	my $file = shift;
	my $ids_ref = shift;
	my %return;
	my $debug = 1;
	open (IN, "$file") or die "can't open file $file\n";
	while(<IN>)
	{
		next if /^\s+$/;
		chomp; 
		my $id = join(":", (split /\t/, $_)[0,1]);
		print STDERR 'info ID: ',$id,"\n" if $debug; $debug = 0;
		#die 'Not defined in ids_ref: ', $id unless exists $ids_ref->{$id};
		next unless exists $ids_ref->{$id};
		$return{$id} = $ids_ref->{$id};
	}
	close IN;
	return %return;
}

sub get_data
{
	my ($feature_file, $info_ref, $out) = @_;
	open (IN, $feature_file) or die;
	open (OUT, ">$out") or die "can't open file $out\n";
	my $count = 0;
	my %record;
	my $debug = 1;
	while(<IN>)
	{
		next if /^\s+$/;
		$count++;
		my @t = split/\t/,$_;
		$record{$count} = join("\t",@t);
	}
	close IN;
	foreach my $id (keys %{$info_ref})
	{
		my $index = $info_ref->{$id};
		print $id,"\t", $index,"\n";
		print OUT $record{$index};
	}
	close OUT;
}







