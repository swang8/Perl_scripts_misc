#!/usr/bin/perl -w
use strict;
my $proj = shift;
$proj = "fillin" unless $proj=~/\S/;

my $header=qq(<head>
  <title></title>
    <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
          <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
            <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
              <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/v/bs4/dt-1.10.18/datatables.min.css"/>
                <script type="text/javascript" src="https://cdn.datatables.net/v/bs4/dt-1.10.18/datatables.min.js"></script>

                  <script>
                     \$(document).ready(function () {
                           \$('#varcount').DataTable(
                               {
                                   "scrollY":        "400px",
                                   "scrollCollapse": true,
                                   searching: false,
                                   "paging":         false
                                                                       }
                                                                         );
                     });
                       </script>
            </head>
            <body>
            <div class="container">
              <div class="row">
                      <div id="logo" class="col-xs-3">
                                      <a href="http://agriliferesearch.tamu.edu/"><img src="/media/image/logo.png" alt="Texas A&amp;M AgriLife Research" class="img-responsive"/></a>
                                              </div>
                                                      <div id="logo" class="col-xs-9">
                                                                      <a href="http://txgen.tamu.edu/"><img src="/media/image/txgen_logo2.png" alt="Genomics and Bioinformatics Services" style="width:30%;" class="img-responsive pull-right"/></a>
                                                                              </div>
                                                                                </div>
                                                                                <hr>
                                                                                <h2>Project information</h2>
                                                                                <ul>
                                                                                <li>Project name:  <code>$proj</code> </li>
                                                                                </ul>
                                                                                <h2>Variation calling</h2>
                                                                                <div class="col-md-12">
                                                                                <div class="col-md-6"><a href="/shichen/agseq_workflow.png" target="_blank"><img src="/shichen/agseq_workflow.png" class="img-thumbnail" /></a> </div>
                                                                                <div class="col-md-6">
                                                                                <ul>
                                                                                <li><code>RAW</code> variations filtered with Missing (&lt 50%) and MAF ( &gt 5%): <br> <a href="agseq_filtered_MaxMissing0.5_MinMAF0.05.vcf">${proj}_agseq_filtered_MaxMissing0.5_MinMAF0.05.vcf</a></li>
                                                                                <p>Note: This file is the starting point for imputation. After imputation, additional filtering may be applied.</p>
                                                                                <li>Reference genome: <a href="" target="_blank"> </a></li>
                                                                                </ul></div>
                                                                                </div>
);
print $header;

# get count table
my $count_file="agseq_filtered_MaxMissing0.5_MinMAF0.05.vcf.var.count.txt";
my @arr = split /\n/,  `cat $count_file`;
print "<div class=\"col-md-12\"><h3>Table 1. The number of variations for each chromosome</h3><table id=\"varcount\" class=\"table table-striped table-bordered\">\n";
print "<thead class=\"thead-dark\"><tr><th>Chromosome</th><th>#Variation</th></tr></thead>\n<tbody>\n";
map{
    my @p = split /\s+/,$_; 
    foreach my $ind(0..$#p){$p[$ind] = "<td>".$p[$ind]."</td>"}
    print "<tr>", @p, "</tr>";
    }@arr;
print "</tbody>\n</table>\n</div>";

print qq(
<div class="row col-md-12">
<h3>Fig 1. The distribution of missing rate per marker and per sample BEFORE imputation.</h3>
<div class="col-md-6">
<a href="Missing_rate.txt.pdf"><img src="Missing_rate.txt.jpeg" class="img-fluid img-thumbnail"></a>
</div>
<div class="col-md-6">
<a href="sample_missing.txt.pdf"><img src="sample_missing.txt.jpeg" class="img-fluid img-thumbnail"></a>
</div>
</div>
<h2>Imputation </h2>
Imputation was performed using Beagle V4.0 with default parameters. The produced Genotype Probability (GP) may be used as a filtering criteria for selecting high quality imputed genotypes.
<br>Please refer to the imputation evaluation figures to choose the best GP cutoff. By default we perform filtering with GP >= 0.9.
<h3>Imputed VCF, no filter applied</h3>
);

# get imputed vcf files;
my @gz_files = <imputed/*.vcf.gz>;
my @gz_list = map{"<li> <a href=\"$_\">" . $_. "</a>" }@gz_files;
print join("\n", "<ul>", @gz_list, "</ul>"), "\n";

# get filtered  imputed vcf
print qq(<h3>Imputed VCF, filtered with GP >= 0.9</h3>), "\n";
my @gp_vcf = <imputed/*GPfiltered_0.9.vcf>;
my @gp_list = map{"<li> <a href=\"$_\">" . $_. "</a>"}@gp_vcf;
print join("\n", "<ul>", @gp_list, "</ul>"), "\n";

my $date = localtime(time);
my $year = (split /\s+/, $data)[-1];
# print the last part
print qq(
<div class="row">
<h3>Fig 2. The distribution of missing rate per marker and per sample AFTER imputation.</h3>
<div class="col-md-6">
<a href="GP_0.9.Missing_rate.txt.pdf"><img src="GP_0.9.Missing_rate.txt.jpeg" class="img-fluid img-thumbnail"></a>
</div>
<div class="col-md-6">
<a href="GP_0.9_sample_missing.txt.pdf"><img src="GP_0.9_sample_missing.txt.jpeg" class="img-fluid img-thumbnail"></a>
</div>
</div>
<h4>After filtering with <code>Genotype Probability, GP </code>, additional filtering may be applied to the imputed VCF based on missing or MAF.</h4>
<hr>
<h3>Imputation evaluation</h3>
To evaluate how the imputation performs, a random 3% of genotypes were masked as missing, then imputed with Beagle V4.0. 
<div class="row col-md-12">
            <div class="col-md-4" align="center"><button type="button" class="btn btn-outline-black waves-effect filter" >Overall accuracy with different GP cutoff</button> <a href="imp_eval/imputation_eval.1.tsv.sum.table.csv.accuracy_sum_up.pdf"><img src="imp_eval/imputation_eval.1.tsv.sum.table.csv.accuracy_sum_up.jpeg" class="img-fluid img-thumbnail"></a> </div>
            <div class="col-md-4" align="center"><button type="button" class="btn btn-outline-black waves-effect filter" >The proportion of each type of genotype imputation</button> <a href="imp_eval/imputation_eval.1.tsv.sum.table.csv.pdf"><img src="imp_eval/imputation_eval.1.tsv.sum.table.csv.jpeg" class="img-fluid img-thumbnail"></a> </div>
            <div class="col-md-4" align="center"><button type="button" class="btn btn-outline-black waves-effect filter" >Imputation accuracy realated to allele frequency and GP cutoff</button> <a href="imp_eval/imputation_eval.1.tsv_AF.txt.pdf"><img src="imp_eval/imputation_eval.1.tsv_AF.txt.jpeg" class="img-fluid img-thumbnail"></a> </div>
            </div>
            </div>
            <hr>
            <footer align="center"><p>Prepared by TXGEN, $year</p></footer>
            </body>
            </html>
);
