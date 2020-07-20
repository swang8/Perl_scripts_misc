#!/usr/bin/perl -w
use strict;
use File::Basename;
my $proj = shift;
$proj = "fillin" unless $proj=~/\S/;

my $header=qq(
<head>
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
                                   	"scrollY":        "600px",
                                   "scrollCollapse": true,
                                   searching: false,
                                   "paging":         false
                                                                       }
                                                                         );
                     });
                       </script>
        <link rel="stylesheet" href="Template_Web_v08_MB.css" />
        <style>
                        /* Remove the navbar's default margin-bottom and rounded borders */
                        .navbar {
                            margin-bottom: 0;
                            border-radius: 0;
                            background-color: white !important;
                            border: 0;
                        }
                        .genotitle {
                            font-size:2.9vw;
                        }
                        .genosubtitle {
                            font-size:1.5vw;
                        }
                        nav .navbar-nav li a{
                            color: #00549F !important;
                            background-color: white !important;
                            font-weight: bold;
                          }
                    pre {
                        text-align: left;
                    }
                    /* Add a gray background color and some padding to the footer */
                    footer {
                        padding: 0.5em;
                        font-size: 14px;
                        text-align: center;
                        background-color:#00549F;
                        color:#FFFFFF;
                        margin-down: 0.5em;
                    }
                    footer a:visited, td.footer a:link, td.footer a:hover, td.footer a:active  {
                        color: #FFFFFF;
                        text-decoration: none ;
                    }
                    .carousel-inner img {
                        width: 100%; /* Set width to 100% */
                        margin: auto;
                        min-height:200px;
                    }
                    /* Hide the carousel text when the screen is less than 600 pixels wide */
                    \@media (max-width: 600px) {
                        .carousel-caption {
                            display: none;
                        }
                    }
                    ul {
                          list-style-type: disc;
                          overflow: hidden;
                          display:block;
                          margin:0 auto;
                        }
                    li {
                        text-align: left;
                    }
                        body {
                            font-family: Literata,Helvetica,Arial,sans-serif;
                            font-size: 14px;
                            font-style: normal;
                            font-variant: normal;
                            //text-align:center;
                            //background-color: #FAFFFA;
                            //background: #FAFFFA;
                            //background: radial-gradient(#EAEAFF, #EAFFEA);
                          }
                        table.main {
                            text-align:left;
                            border-spacing: 0px;
                            margin: 0px auto auto auto;
                            background-color:#FFFFFF;
                        }
                        td.footer {
                            padding: 1em;
                            font-size: 13px;
                            text-align: center;
                            background-color:#00549F;
                            color:#FFFFFF;
                        }
                        td.footer a:visited, td.footer a:link, td.footer a:hover, td.footer a:active  {
                            color: #FFFFFF;
                            text-decoration: none ;
                        }
                        h1 {
                            font-family: Roboto,"Times New Roman",Georgia,serif;
                            color:#00549F;
                            font-size: 28px;
                            font-weight: bold;
                            text-align: center;
                            margin-top: 0em;
                            margin-bottom: 0em;
                            padding: 0.3em 0em 0em 0em;
                        }
                        h2 {
                            font-family: Roboto,"Times New Roman",Georgia,serif;
                            font-weight: bold;
                            font-size:18px;
                            color:#00549F !important;
                            width=100%;
                            text-align: left;
                        }
                        h3 {
                            font-family: Roboto,"Times New Roman",Georgia,serif;
                            font-weight: bold;
                            font-size:14px;
                            color:#00549F !important;
                            width=100%;
                            text-align: left;
                        }
                        p {
                            display: block;
                            margin: 1em 0px 1em 0px;
                            text-align: left;
                        }
                        hr {
                            border:0px;
                            border-top:1px solid #c4d600;
                            height:2px;
                            color:#c4d600;
                            background:#c4d600;
                            margin:0.5em 0em 0.5em 0em;
                        }
                        .container {
                            background-color: #FFFFFF;
                            padding: 0em;
                            max-width: 80%;
                        }
                        .row {
                            margin: 0em;
                        }
        </style>
            </head>
            <body>
        <div class="container "> <!-- WHOLE CONTAINER STARTS HERE -->
        <!-- HEADER - START -->
        <div class="top">
        <img src="/media/image/txgen_web_banner.png" width=100% class="fluid-img">
        </div>
                                                                              <hr>
                                                                                <h2>Project information</h2>
                                                                                <ul>
                                                                                <li>Project name:  <code>$proj</code> </li>
                                                                                <li>PI:  <b>PI</b> </li>
                                                                                <li>Project description:  Description goes here. </li>
                                                                                </ul>
                                                                                <h2>Variation calling</h2>
                                                                                <div class="col-md-12">
                                                                                <div class="col-md-6"><a href="/shichen/agseq_workflow.png" target="_blank"><img src="/shichen/agseq_workflow.png" class="img-thumbnail" /></a> </div>
                                                                                <div class="col-md-6">
                                                                                <ul>
                                                                                <li><code>RAW</code> variations filtered with Missing (&lt 50%) and MAF ( &gt 5%): 
                                                                                  <ul>
                                                                                    <li>VCF: <a href="agseq_filtered_MaxMissing0.5_MinMAF0.05.vcf">${proj}_agseq_filtered_MaxMissing0.5_MinMAF0.05.vcf</a> </li>
                                                                                    <li>HMP: <a href="agseq_filtered_MaxMissing0.5_MinMAF0.05.hmp.txt">${proj}_agseq_filtered_MaxMissing0.5_MinMAF0.05.hmp.txt</a></li>
                                                                                  </ul>
                                                                                </li>
                                                                                <p>Note: This file is the starting point for imputation. After imputation, additional filtering may be applied.</p>
                                                                                <li>Reference genome: <a href="" target="_blank"> </a></li>
<li>Analysis steps:</li>
<ol style="font-size:12px">
<li>QC: Trimmomatic v0.38; Quality filtering and adapter trimming, ”LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36”</li>
<li>Mapping: Bowtie2 v2.3.4;
Alignment to the reference genome, “--end-to-end –very-sensitive”</li>
<li>Processing: SAMTools v1.19 and  PICARD v1.16;
Sorting, local Realignment, MQ filtering (MQ>5), et al.
</li>
<li>Calling variation and genotyping: GATK (v3.5)  HaplotypeCaller; “-drf BadMate -drf DuplicateRead -U ALLOW_N_CIGAR_READS”
</li>
<li>Filtering: Only keep variations with <50% of missing and MAF > 5%
</li>
<li>Imputation with Beagle V4.0 (default parameters)
</li>
<li>Filtered based on the Genotype Probability (GP >= 0.9)
</li>
<li>Additional filtering (upon request):
Proportion of missing data, MAF, et al.
</li>
</ol>
                                                                                </ul></div>
                                                                                </div>
);
print $header;

# get count table
my $count_file=<*.var.count.txt>;
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

<h3>Table 2. Alignment summary</h3>
<div class="row col-md-12" style="height: 500px; overflow-y: scroll;">
</div>

<h2>Imputation </h2>
<p>Imputation was performed using Beagle V4.0 with default parameters. The produced Genotype Probability (GP) may be used as a filtering criteria for selecting high quality imputed genotypes.
<br>Please refer to the imputation evaluation figures to choose the best GP cutoff. By default we perform filtering with GP >= 0.9. </p>
<h3>Imputed VCF, no filter applied</h3>
);

# get imputed vcf files;
my @gz_files = <imputed/*.vcf.gz>;
my @gz_list = map{"<li> <a href=\"$_\">" . $proj . "_" . basename($_). "</a>" }@gz_files;
print join("\n", "<ul>", @gz_list, "</ul>"), "\n";

# get filtered  imputed vcf
print qq(<h3>Imputed VCF, filtered with GP >= 0.9</h3>), "\n";
my @gp_vcf = <imputed/*GPfiltered_0.9.vcf>;
my @gp_list = map{"<li> <a href=\"$_\">" . $proj. "_". basename($_) . "</a>"}@gp_vcf;
print join("\n", "<ul>", @gp_list, "</ul>"), "\n";

my $date = localtime(time);
my $year = (split /\s+/, $date)[-1];
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
<h2>Imputation evaluation</h2>
<p>To evaluate how the imputation performs, a random 3% of genotypes were masked as missing, then imputed with Beagle V4.0. </p>
<div class="row col-md-12">
            <div class="col-md-4" align="center"><figure class="figure" > <figcation class="figcation"> Overall accuracy with different GP cutoff</> <a href="imp_eval/imputation_eval.1.tsv.sum.table.csv.accuracy_sum_up.pdf"><img src="imp_eval/imputation_eval.1.tsv.sum.table.csv.accuracy_sum_up.jpeg" class="img-fluid img-thumbnail"></a>  </figure> </div>
                        <div class="col-md-4" align="center"><figure class="figure" > <figcation class="figcation"> The proportion of each type of genotype imputation </> <a href="imp_eval/imputation_eval.1.tsv.sum.table.csv.pdf"><img src="imp_eval/imputation_eval.1.tsv.sum.table.csv.jpeg" class="img-fluid img-thumbnail"></a>  </figure> </div>
                                    <div class="col-md-4" align="center"><figure class="figure" > <figcation class="figcation"> Accuracy realated to allele frequency and GP cutoff</> <a href="imp_eval/imputation_eval.1.tsv_AF.txt.pdf"><img src="imp_eval/imputation_eval.1.tsv_AF.txt.jpeg" class="img-fluid img-thumbnail"></a>  </figure> </div>
            </div>
                                <div class="col-sm-12">
                                <hr>
                                <footer>
                                    (C) 2019 TxGen - Genomics and Bioinformatics - Texas A&M Agrilife, College Station, TX - <a href="https://www.txgen.tamu.edu" target="_blank">https://www.txgen.tamu.edu</a>
                                </footer>
                                </div>
 </div>
            </body>
            </html>
);
