#!/usr/bin/perl -w
use strict;
use Bio::Taxon;
use Bio::DB::Taxonomy;
use Bio::Tree::Tree;

unless (@ARGV){
  print qq(
  ## given gb ids like "gb|AC149418.2|", query the ncbi databse to get the taxonomy id and lineage description;
  ## input file have one gb id on each line;
    perl $0 input_file
  ), "\n";
  exit;
}
my $file = shift;
open(IN, $file) or die $!;

my $dbh = Bio::DB::Taxonomy->new(-source   => 'flatfile',
                                   -directory=> '/home/DNA/taxonomy',
                                   -nodesfile=> '/home/DNA/taxonomy/nodes.dmp',
                                   -namesfile=> '/home/DNA/taxonomy/names.dmp');

while(<IN>){
  chomp;
  my $gb = $_;
  my $query = q(curl "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=GBID&rettype=fasta&retmode=xml");
  $query =~ s/GBID/$gb/;
  print STDERR $query, "\n";
  my $res = `$query`;
  ##<TSeq_taxid>169999</TSeq_taxid>
  my $taxon_id = $1 if $res =~ /<TSeq_taxid>(\d+)<\/TSeq_taxid>/;
  #print $gb, "\t", $taxon_id, "\n";
  my $taxon = $dbh->get_taxon(-taxonid => $taxon_id);
  my $tree_functions = Bio::Tree::Tree->new();
  my @lineage = $tree_functions->get_lineage_nodes($taxon);
  my $lineage = $tree_functions->get_lineage_string($taxon);
  print $gb, "\t", $taxon_id,  "\t", $lineage, "\n";
 
  sleep(1);
}
close IN;
