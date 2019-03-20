#!/usr/bin/perl -w
use strict;
use File::Basename;
use lib '/home/shichen.wang/perl5/lib/perl5';
use JSON::Parse 'json_file_to_perl';
use XML::Simple;
use Data::Dumper;
use Cwd;
use FindBin;
use Getopt::Long;

my $star_bar = '*' x 80;
my $usage =  qq ($star_bar
Usage:
$0 -p 18789Avi -r <pacbio_sequence_folder, i.e, /data4/pacbio/r54092_20160921_211039>:<cell_1>:<cell_2> ...\n

Examples:
* To generate report for all cells of the run:
  $0 -p 18987Avi -r /data4/pacbio/r54092_20160921_211039
  This will generate report for all cells in the folder r54092_20160921_211039;

* To generate report for all cells of multiple runs:
  $0 -p 18987Avi -r /data4/pacbio/r54092_20160921_211039  /data4/pacbio/r54092_20180921_298765
  This will generate report for all cells in the folder r54092_20160921_211039 and /data4/pacbio/r54092_20180921_298765

* To generate report for certain cell(s) of the runs:
  $0 -p 18987Avi -r  /data4/pacbio/r54092_20160921_211039:1_A01:2_B02   /data4/pacbio/r54092_20180921_298765:3_C03

* To run BLAST
RUNBLAST=1 $0 -p 18987Avi -r /data4/pacbio/r54092_20160921_211039

The output will be gereated in the working directory while the perl script is running,
with the folder named as r54092_processed_DATE-STRING, i.e., r54092_processed_Wed_Mar_20_13_36_52_2019
This folder may be copyed to the PI's downloadable folder.

shichen\@tamu
01/05/2017 first draft
04/20/2019 add support for multiple runs
$star_bar
);

# get options
my $proj_id;
my @runs;

GetOptions(
    'proj=s' => \$proj_id,
    'runs=s@' => \@runs
);

unless ($proj_id and @runs){
  print $usage;
  exit;
}

# prepare the report directory
my $localtime=localtime(time);  
my @p=split /\s+/,$localtime;
my $report_dir = "pacbio_" . $proj_id . "_". join("", @p[1,2,-1]);
mkdir($report_dir) unless -d $report_dir;
my $output_html =  $report_dir . "/index.html";
open (my $HTML, ">$output_html") or die "$output_html error!";
my $header_printed = 0;

my $poly_read_count_all = 0;
my $sub_read_count_all = 0;
my $poly_read_total_all = 0;
my $sub_read_total_all = 0;
my $num_runs = 0;
my $num_cells = 0;
my %run_id;
my %cell_id;

my @summary;
my @page;

foreach my $opt (@runs) {
    # getting the data dir and cell names
    my ($dir, @selected_cells) = split /:/, $opt;
    $dir =~ s/\/$//;
    my $run = basename($dir); # r54092_20160921_211039
    unless (exists $run_id{$run}) {$num_runs ++; $run_id{$run}=1}
    map{unless (exists $cell_id{$run.":".$_}){$num_cells++; $cell_id{$run.":".$_}=1}  }(@selected_cells);
    #$dir = Cwd::abs_path($dir);
    print STDERR "Selected cells for run $run : ", @selected_cells >0?join(" ", @selected_cells):"None, will take all detected.", "\n";

    my $pacbio_data_root = "/data4/pacbio";
    my $second_analysis_dir = $pacbio_data_root . "/000";

    my %analysis_dir_properties = get_properties($second_analysis_dir);

    my @sub_dirs = <$dir/*>;
    my @cells = grep {-d $_} @sub_dirs;
    print STDERR "Detected cells for run $run : ", join(" ", map{basename($_)}@cells), "\n";

    my %selected = map{$_, 1}@selected_cells;
    @cells = grep{exists $selected{basename($_)} }@cells if @selected_cells > 0;

    my $output_dir = $report_dir . "/" . join("-", basename($dir), map{basename($_)}@cells);
    mkdir($output_dir) unless -d $output_dir;

    # generate zipped file
    my $zip = basename($dir) . "_" . join("-", (map{basename($_)}@cells)) . ".tar";
    my $zip_dir = $output_dir . "/" . random_str();
    mkdir ($zip_dir) unless -d $zip_dir;
    #my $zip_cmd = "tar --exclude=\".*\" --exclude=\"*scraps.*\"  -cvf  $zip_dir/$zip -C $dir " . join(" ", (map{basename($_)}@cells));# print STDERR $zip_cmd, "\n";
    my $zip_cmd = "tar  -cvf  $zip_dir/$zip -C $dir " . join(" ", (map{basename($_)}@cells));# print STDERR $zip_cmd, "\n";
    print STDERR $zip_cmd, "\n";
    die if system($zip_cmd);
    $zip = basename($zip_dir) . "/" . $zip;

    ## get figures and tables for each cell
    foreach my $cell (@cells) {
        print STDERR "Processing ". basename($cell). " for run $run ...\n";
        my @files = <$cell/*xml>;
        next unless @files;
        my $subread_bam = (<$cell/*subread*bam>)[0];
        my $metadata_xml; map{$metadata_xml = $_ if /run.metadata/}@files;

        my $subset_xml; map{$subset_xml = $_ if /subreadset/}@files;
        my $analysis_dir; map{print STDERR "\t", $_, "\n"; $analysis_dir = $_ if $analysis_dir_properties{$_}->[1] eq $subset_xml}keys %analysis_dir_properties;

        my $pbscala_stdout = $analysis_dir . "/pbscala-job.stdout";

        my $xml = new XML::Simple;
        my $data = $xml->XMLin($subset_xml);
        my $r = $data->{"pbds:DataSetMetadata"}->{"Collections"}->{"CollectionMetadata"}->{"RunDetails"};
        my ($run_start, $stamp_name, $run_id) = ($r->{"WhenCreated"}, $r->{"TimeStampedName"}, $r->{"Name"});
        my $subset_str = `cat $subset_xml`;
        my $lib_cell = $1 if $subset_str=~/pbds\:SubreadSet.*?Name="(.*?)"/;
        $lib_cell =~ s/\s+/_/g;
        my ($lib_name, $cell_name) = ($1, $2) if $lib_cell=~/^(.*)\-(Cell\d+)$/;
        print STDERR join("\t", "Test", $lib_cell, $lib_name, $cell_name), "\n";
        ##
        ## unless($header_printed){print_header($HTML, $run_start, $stamp_name, $lib_name, $run_id); $header_printed = 1}

        my $polymerase_plot = $analysis_dir . "/dataset-reports/filter_stats_xml/readLenDist0.png";
        my $insert_plot = $analysis_dir . "/dataset-reports/filter_stats_xml/insertLenDist0.png";
        mkdir( "$output_dir/" . basename($cell)) unless -d "$output_dir/" . basename($cell);
        system("cp $polymerase_plot $insert_plot $output_dir/" . basename($cell));
        $polymerase_plot = basename($output_dir) . "/" .basename($cell) . "/". basename($polymerase_plot);
        $insert_plot = basename($output_dir) . "/" . basename($cell). "/". basename($insert_plot);
        my ($poly_read_total, $poly_read_count, $poly_read_mean, $poly_read_N50) = get_polymerase_count($analysis_dir . "/dataset-reports/filter_stats_xml/filter_stats_xml.json");


        my ($sub_read_total, $sub_read_N50, $sub_read_mean, $sub_read_count) = get_stats_from_bam($subread_bam);

        push @summary, [$run, $lib_cell, $poly_read_count, $poly_read_total, $sub_read_count, $sub_read_total];

        $poly_read_count_all += $poly_read_count;
        $sub_read_count_all += $sub_read_count;
        $poly_read_total_all += $poly_read_total;
        $sub_read_total_all += $sub_read_total;

        push @page, "<div class=\"run\">";
        push @page, "<h2>", $run, "</h2>\n";
        push @page, "<li> <div class=\"lane\">", basename($cell), "</div></li>";
        push @page, qq(
        <h4>Sequencing summary:</h4>
        <table class="table table-bordered table-condensed">
          <thead>
            <tr>
              <th></th>
              <th>Polymerase read</th>
              <th>Subread</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Number reads</td>
              <td>$poly_read_count</td>
              <td>$sub_read_count</td>
            </tr>
            <tr>
              <td>Total bases</td>
              <td>$poly_read_total</td>
              <td>$sub_read_total</td>
            </tr>
            <tr>
              <td>Mean length, bp</td>
              <td>$poly_read_mean</td>
              <td>$sub_read_mean</td>
            </tr>
            <tr>
              <td>N50, bp</td>
              <td>$poly_read_N50</td>
              <td>$sub_read_N50</td>
            </tr>
          </tbody>
        </table>
        <p>
        );
        #add plot
        push @page, qq(
        <table class="table table-condensed">
        <tr>
        <td>Polymerase read length<br><img src="$polymerase_plot" class="img-rounded" alt="" width="304" height="236"></td>
        <td>Insert length<br><img src="$insert_plot" class="img-rounded" alt="" width="304" height="236"></td>
        </tr>
        </table>
        );

        push @page, "</div>\n"; # class=run

        push @page, qq(
        <li><div class="documentation">Retrieve data</div>
        You may click <a href="$zip"> this link </a> or use the wget command.
                <pre>
        <script type="text/javascript">document.write(dl_cmd(\"$zip\"));</script>
        </pre>
        </li>
        );

        # run blast
        if (exists $ENV{RUNBLAST}){
              my @bams = <$cell/*subreads.bam>;
              foreach my $bam (@bams){
                  my $blast_output = $output_dir . "/" . basename($cell) . ".blast.out";
                  my $blast_sum = $output_dir . "/" . basename($cell) . ".blast.sum.txt";
                  my $cmd = "bamToFastq -i $bam -fq /dev/stdout | head -n 10000 |seqtk seq -A |blastn -db nt -num_threds 10 -outfmt \'6 qseqid stitle qcovs \' >$blast_output";
                  system($cmd);
                  `sh $FindBin::Bin/../lib/summarize_blast.sh $blast_output >$blast_sum`;
              }
        }

    };

}

###################
## output
&print_header($HTML, $proj_id);

my $gb = sprintf("%.1f", $sub_read_total_all / 10**9 ); 

print $HTML qq(
<pre>
Total runs: $num_runs 
Total cells: $num_cells 
Total yield: $gb Gb
</pre>
);
# summary table
print $HTML "<table class=\"table table-striped table-condensed\">\n";
print $HTML qq(
<thead>
  <tr>
    <th>Run</th>
    <th>Cell</th>
    <th>Polymerase read count</th>
    <th>Polymerase read length</th>
    <th>Subread count</th>
    <th>Subread total length</th>
  </tr>
</thead>
<tbody>
);
foreach (@summary) {
  my @arr = @$_;
  map{
    $arr[$_] = format_number($arr[$_]) unless $arr[$_]=~/\D/;
    $arr[$_] = "<td>" . $arr[$_]. "</td>"
  }0..$#arr;
  print $HTML "<tr>\n", join("\n", @arr), "\n</tr>\n";
}

$poly_read_count_all = format_number($poly_read_count_all);
$poly_read_total_all = format_number($poly_read_total_all);
$sub_read_count_all = format_number($sub_read_count_all);
$sub_read_total_all = format_number($sub_read_total_all);

print $HTML qq(
<tr>
  <td>Total</td>
  <td></td>
  <td>$poly_read_count_all</td>
  <td>$poly_read_total_all</td>
  <td>$sub_read_count_all</td>
  <td>$sub_read_total_all</td>
</tr>
);

print $HTML "</tbody>\n</table>\n";

print $HTML join("\n", @page), "\n";

# print document and foot
print $HTML qq(<li><div class="documentation">Documentation</div>
        	<ul>
        	<li><a href="http://www.pacb.com/wp-content/uploads/2015/09/Pacific-Biosciences-Glossary-of-Terms.pdf">PacBio Terminology</a></li>
        	<li><a href="https://github.com/PacificBiosciences/Bioinformatics-Training/wiki">Bioinformatics Tutorial for PacBio data</a></li>
               <img src="/media/image/pacbio.png", width=500>
        	</ul>
        </li>
        );
print $HTML "<hr>", "<div id=\"footer\">Texas A&M AgriLife Genomcis and Bioinformatics Service. &copy 2017</div>";
print $HTML "</div></body></html>";

close $HTML;

## generate a file in the directory when the report is done.
my $time = localtime(time);
print STDERR "\n\n$time Done!\nReport is in $report_dir !\n\n";
open (DONE, ">$report_dir/report.done.txt") or die $!;
print DONE $time, " Done\n\n";
close DONE;
################

## subroutines
sub get_stats_from_bam {
  my $bam = shift or die;
  print STDERR "Bam file: $bam \n";
  my $samtools =  `which samtools`   || '/home/shichen.wang/Tools/bin/samtools';
  chomp $samtools;
  print STDERR "$samtools view $bam\n";
  open (my $IN, "$samtools view $bam |" ) or die $!;
  my @regions; my $total_length = 0; my $read_mean = 0; my $read_count = 0;
  while(<$IN>){
    my $id = $1 if /^(\S+)/;
    # m54092_161220_211206/4194368/0_11
    my @p = split /\//, $id;
    my @arr = split /_/, $p[-1];
    my $region_len = $arr[1] - $arr[0];
    $read_count ++;
    $total_length += $region_len;
    push @regions, $region_len;
  }
  $read_mean = int($total_length / $read_count);
  @regions = sort {$a <=> $b} @regions;
  my $N50 = $regions[int((scalar @regions)/2)];
  return($total_length, $N50, $read_mean, $read_count);
}

sub all_exist {

}

sub get_properties {
  my $root = shift;
  my %return;
  my @dirs = <$root/*>;
  foreach my $d (@dirs){
    my $datastore = $d."/datastore.json";
    next unless -e $datastore;
    my $p = json_file_to_perl($datastore);
    #print STDERR Data::Dumper->Dump([$p], "datastore");
    my $xml = $p->{files}->[0]->{path};
    my $proj_name = $p->{files}->[0]->{name};
    $return{$d} = [$proj_name, $xml];
    print STDERR join("\t", $d, $proj_name, $xml),"\n";
  }
  return %return;
}

sub print_header {
  my $fh = shift;
  my $p = shift;
  print {$fh} qq(
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>$p</title>
          <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
	<link href="/media/css/delivery.css" rel="stylesheet"/>

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
<h2>Project: $p</h2>
);
print STDERR "\tHeadaer printed!\n";
}

sub get_polymerase_count {
  my $file = shift;
  die $file unless -e $file;
  my $p = json_file_to_perl($file);
  return ($p->{attributes}->[0]->{"value"}, $p->{attributes}->[1]->{"value"},$p->{attributes}->[2]->{"value"},$p->{attributes}->[3]->{"value"})
}


sub random_str {
  my @arr=('a'..'z', "-");
  my $n = shift || 10;
  my $str="";
  while($n--){$str .= $arr[int(rand(scalar @arr))]}
  return $str;
}

sub format_number {
  # 189768767834 =>  189,768,767,834
  my $n = shift;
  $n = $n + "";
  $n = reverse $n ;
  $n =~ s/(\S{3})/$1,/g;
  $n=~s/\,$//;
  $n = reverse $n;
  return $n;
}
