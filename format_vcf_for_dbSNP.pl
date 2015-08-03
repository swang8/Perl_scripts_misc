#!/usr/bin/perl -w
use strict;
use Bio::DB::Fasta;


die "perl $0 <ref_fasta> <vcf_files>" unless @ARGV >= 2;

my $fasta = shift;
my @files = @ARGV;

my $gn=Bio::DB::Fasta->new("$fasta");

my $meta_info = qq(# Submitter contact information
# The name and contact information which may be different from the name registered to the handle
TYPE: CONT
HANDLE: EAKHUNOV
NAME: Eduard Akhunov
FAX: 785-532-5692
TEL: 785-532-1342
EMAIL: eakhunov\@ksu.edu
LAB: Wheat Genomics Lab
INST: Kansas State University
ADDR: Department of Plant Pathology, 4024 Throckmorton Plant Sciences Center, Kansas State University
||
TYPE:	PUB
HANDLE:	EAKHUNOV
PMID:	
TITLE:	A Haplotype Map of the Allohexaploid Wheat Genome Reveals Distinct Patterns of Selection on Duplicated Homoeologous Genes
AUTHORS: Katherine W. Jordan, Shichen Wang, Yanni Lun, Laura-Jayne Gardiner, Ron MacLachlan, Pierre Hucl, Krysta Wiebe, Debbie Wong, Kerrie L. Forrest, IWGSC, Andrew G. Sharpe, Christine H. D. Sidebottom, Neil Hall, Christopher Toomajian, Timothy Close, Jorge Dubcovsky, Alina Akhunova, Luther Talbert, Urmil K. Bansal, Harbans S. Bariana, Matthew J. Hayden, Curtis Pozniak, Jeffrey A. Jeddeloh, Anthony Hall, Eduard Akhunov
JOURNAL: Genome Biology
VOLUME:	
PAGES:	
YEAR:	2015
STATUS:	3
|| 
#Provide REQUIRED method used to detect or ascertain variation
TYPE: METHOD
HANDLE: EAKHUNOV
ID: NimblegeneExomeCapture
METHOD_CLASS: Sequence
TEMPLATE_TYPE: Hexaploid
METHOD:Wheat exome capture
||
#Provide population assayed ; copy and paste this section as required for reporting multiple populations.
TYPE: POUPLATION
HANDLE: EAKHUNOV
ID: Diversity
POPULATION: This population includes 62 wheat accessions which are gentically and geographically diverse.
||
#Provide Variation Assay batch details
TYPE:SNPASSAY
HANDLE: EAKHUNOV
BATCH: EXOME_SNP_DISCOVERY
MOLTYPE: Genomic
METHOD: WholeExomeCapture
ORGANISM: Triticum aestivum
||);

my $vcf_header=qq(##fileformat=VCFv4.1
##fileDate=20150202
##handle=EAKHUNOV
##batch=EXOME_SNP_DISCOVERY
##bioproject_id=227449
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Genotype Quality">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth">
##FORMAT=<ID=HQ,Number=2,Type=Integer,Description="Haplotype Quality">);

print STDERR $meta_info, "\n";

print $vcf_header, "\n";
my $CHROM=0;
foreach my $vcf (@files){
  open(IN, $vcf) or die $!;
  while(<IN>){
  	if(/^\#CHROM/){
  		if($CHROM == 0){
  			print $_;
  			$CHROM = 1;
  		}
  	}
  	next if /^\#/;
  	chomp;
  	my @t = split /\s+/,$_;
  	my $vrt = 1; # SNP
  	if (length $t[3] > 1 or length $t[4] > 1){
  		$vrt = 2 # indels
  	}
  	my $flank5 = $gn->seq($t[0], ($t[1]-100)=>($t[1]-1));
	$flank5 = ("N" x (100 - length $flank5) ) . $flank5  if (length $flank5 < 100);
  	my $flank3 = $gn->seq($t[0], ($t[1]+ length($t[3])) => ($t[1]+length($t[3])+100-1));
	$flank5 .= "N" x (100 - length $flank3) if (length $flank3 < 100);
  	$t[2] = join(":", @t[0,1]);
  	$t[7] = "VRT=$vrt" . ";" . "LID=$t[2];" . "FLANK-5=$flank5;FLANK-3=$flank3";
  	
  	print join("\t", @t), "\n";
  }
  close IN;
}
