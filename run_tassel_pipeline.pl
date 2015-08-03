#!/usr/bin/perl -w
use strict;
my $sUsage = qq(
perl $0
<output prefix>
<genotype file>
<phenotype file>
<kinship file>
<structure file>
<Tassel directory>
);
die $sUsage unless @ARGV >= 6;

my ($output_prefix, $genotype_input, $phenotype_input, $kinship_input, $structure_input, $tassel_dir) = @ARGV;
run_gwas($output_prefix, $genotype_input, $phenotype_input, $kinship_input, $structure_input, $tassel_dir);

sub run_gwas
{
	my ($output_prefix, $genotype_input, $phenotype_input, $kinship_input, $structure_input, $tassel_dir) = @_;

	my $libdir = $tassel_dir . '/'. "lib";
	my @jars = <$libdir/*.jar>;
	push @jars , $tassel_dir . '/dist/'. 'sTASSEL.jar';
	my $CP = join(":", @jars);

	my $parameters = '-p "'. $genotype_input .'" -t "'. $phenotype_input. '" -k "' .$kinship_input.  '" -q "'. $structure_input . '" -mlm -mlmOutputFile '. $output_prefix;
	my $cmd = "java -d64 -classpath '$CP' -Xmx4000m net.maizegenetics.pipeline.TasselPipeline $parameters";
	print $cmd, "\n";
	#print $cmd,"\n";
	die $! if system($cmd); 
}