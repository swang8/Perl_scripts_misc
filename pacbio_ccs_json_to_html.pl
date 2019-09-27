#!/bin/perl -w
use strict;
use lib '/home/shichen.wang/perl5/lib/perl5';
use JSON;
use File::Basename;

my $project = shift;
my $file = shift; # the ccs report json: pbreports.tasks.ccs_report.html

my $r = `cat $file`;

my $hr = {};
$hr = JSON::decode_json($r);

print "<h2>", $project, "</h2>\n";
# basic stats
print "<div class=\"row\">\n<div class=\"col-md-6\">";
print "<table class=\"table table-striped table_dark\">\n";
map{
   print "<tr>", "<td>", $_->{value}, "</td><td>", $_->{name}, "</td>\n" 
}@{$hr->{attributes}};
print "</table>";
print "</div>\n</div>\n";

# images
print "<div class=\"row\">\n";

foreach my $plot (@{$hr->{plotGroups}}){

print "<div class=\"col-md-6\">";
print "<div class=\"caption\">", "<h3 style=\"text-align:center\">", $plot->{plots}->[0]->{caption}, "</h3></div>";
print "<img class=\"img-responsive\" src=\"images_${project}/pbreports.tasks.ccs_report/" . $plot->{plots}->[0]->{image} . "\">";
print "</div>\n"
}
print "</div>"; # row div ends

my $dir = dirname($file);
system("cp -r ${dir}/images  images_${project}");

# get bam files
my @bams = <$dir/../tasks/pbccs.tasks.ccs-*/*bam>;
my $out_bam = "${project}_CCS.bam";
my $cmd="samtools merge  $out_bam ". join(" ", @bams);
print STDERR $cmd, "\n";
system($cmd);




