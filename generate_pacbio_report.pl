#!/usr/bin/perl -w
use strict;
use File::Basename;
use lib '/home/shichen.wang/perl5/lib/perl5';
use JSON::Parse 'json_file_to_perl';
use XML::Simple;
use Data::Dumper;
use Cwd;
use FindBin;

my $star_bar = '*' x 80;
my $usage =  qq ($star_bar
Usage:
$0 <pacbio_sequence_folder, i.e, /data4/pacbio/r54092_20160921_211039>   <cell_1>  <cell_2> ...\n

Examples:
* To generate report for all cells of the run:
  $0 /data4/pacbio/r54092_20160921_211039
  This will generate report for all cells in the folder r54092_20160921_211039;

* To generate report for certain cell(s) of the run:
  $0 /data4/pacbio/r54092_20160921_211039 1_A01 2_B02

* To run BLAST
RUNBLAST=1 $0 /data4/pacbio/r54092_20160921_211039 1_A01 2_B02

The output will be gereated in the working directory while the perl script is running, with the folder named as RUN_NAME-Cell1-Cell2, i.e., r54092_20160921_211039-1_A01-2_B02. This folder may be copyed to the PI's downloadable folder.

shichen\@tamu
01/05/2017 first draft
$star_bar
);

my $dir = shift or die $usage;
$dir =~ s/\/$//;
#$dir = Cwd::abs_path($dir);

my @selected_cells = @ARGV;
print STDERR "Selected cells: ", @selected_cells >0?join(" ", @selected_cells):"None, will take all detected.", "\n";

my $pacbio_data_root = "/data4/pacbio";
my $second_analysis_dir = $pacbio_data_root . "/000";

my %analysis_dir_properties = get_properties($second_analysis_dir);

my @sub_dirs = <$dir/*>;
my @cells = grep {-d $_} @sub_dirs;
print STDERR "Detected cells: ", join(" ", map{basename($_)}@cells), "\n";

my %selected = map{$_, 1}@selected_cells;
@cells = grep{exists $selected{basename($_)} }@cells if @selected_cells > 0;

my $output_dir = join("-", basename($dir), map{basename($_)}@cells);
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

# run blast
if (exists $ENV{RUNBLAST}){
    foreach my $cell (@cells){
        my @bams = <$cell/*subreads.bam>;
        foreach my $bam (@bams){
            my $blast_output = $output_dir . "/" . basename($cell) . ".blast.out";
            my $blast_sum = $output_dir . "/" . basename($cell) . ".blast.sum.txt";
            my $cmd = "bamToFastq -i $bam -fq /dev/stdout | head -n 10000 |seqtk seq -A |blastn -db nt -num_threds 10 -outfmt \'6 qseqid stitle qcovs \' >$blast_output";
            system($cmd);
            `sh $FindBin::Bin/../lib/summarize_blast.sh $blast_output >$blast_sum`;
        }
    }
}
my $output_html = $output_dir . "/index.html";
open (my $HTML, ">$output_html") or die "$output_html error!";
my $header_printed = 0;

foreach my $cell (@cells) {
  print STDERR "Processing $cell ...\n";
  my @files = <$cell/*xml>;
  next unless @files;
  my $subread_bam = (<$cell/*subread*bam>)[0];
  my $metadata_xml; map{$metadata_xml = $_ if /run.metadata/}@files;
  #my $r = `cat $metadata_xml`; 
  #my ($run_start, $stamp_name, $run_id) = $r=~/pbdm:Run Status=.*WhenStarted="(\S+)".*TimeStampedName="(\S+)".*Name="(\S+)"/;
  #unless($header_printed){print_header($HTML, $run_start, $stamp_name, $run_id); $header_printed = 1}
  
  my $subset_xml; map{$subset_xml = $_ if /subreadset/}@files;
  my $analysis_dir; map{print STDERR "\t", $_, "\n"; $analysis_dir = $_ if $analysis_dir_properties{$_}->[1] eq $subset_xml}keys %analysis_dir_properties;
  
  my $pbscala_stdout = $analysis_dir . "/pbscala-job.stdout";
  ##
  #my $r = `cat $pbscala_stdout`;
  #my $info_str = $1 if $r =~/Successfully entered SubreadSet SubreadServiceDataSet\((.*)\)/;
  #my @info_arr = split /,/, $info_str;
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
  unless($header_printed){print_header($HTML, $run_start, $stamp_name, $lib_name, $run_id); $header_printed = 1}

  my $polymerase_plot = $analysis_dir . "/dataset-reports/filter_stats_xml/readLenDist0.png";
  my $insert_plot = $analysis_dir . "/dataset-reports/filter_stats_xml/insertLenDist0.png";
  mkdir( "$output_dir/" . basename($cell)) unless -d "$output_dir/" . basename($cell);
  system("cp $polymerase_plot $insert_plot $output_dir/" . basename($cell));
  $polymerase_plot = basename($cell) . "/". basename($polymerase_plot);
  $insert_plot = basename($cell). "/". basename($insert_plot);
  my ($poly_read_total, $poly_read_count, $poly_read_mean, $poly_read_N50) = get_polymerase_count($analysis_dir . "/dataset-reports/filter_stats_xml/filter_stats_xml.json");


  my ($sub_read_total, $sub_read_N50, $sub_read_mean, $sub_read_count) = get_stats_from_bam($subread_bam);
  # my ($sub_read_total, $sub_read_N50, $sub_read_mean, $sub_read_count) = (21123456, 2345, 3421, 9900);
  
  print $HTML "<li> <div class=\"lane\">", basename($cell), "</div></li>";
  print $HTML qq(
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
print $HTML qq(
<table class="table table-condensed">
<tr>
<td>Polymerase read length<br><img src="$polymerase_plot" class="img-rounded" alt="" width="304" height="236"></td>
<td>Insert length<br><img src="$insert_plot" class="img-rounded" alt="" width="304" height="236"></td>
</tr>
</table>
);

};

## add downlod link
print $HTML qq(
<li><div class="documentation">Retrieve data</div>
You may click <a href="$zip"> this link </a> or use the wget command.
        <pre>
<script type="text/javascript">document.write(dl_cmd(\"$zip\"));</script>
</pre>
</li>

<li><div class="documentation">Documentation</div>
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
print STDERR "\n\n$time Done!\nReport is in $output_dir !\n\n";
open (DONE, ">$output_dir/report.done.txt") or die $!;
print DONE $time, " Done\n\n";
close DONE;

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
  my ($run_start, $stamp_name, $lib_name, $run_id) = @_;
  print {$fh} qq(
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>$stamp_name</title>
          <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
	<link href="/media/css/delivery.css" rel="stylesheet"/>

<script type="text/javascript">
function basename(path) {
	return path.replace(/\\\\/g,'/').replace( /.*\\//, '' );
}
function dirname(path) {
	return path.replace(/\\\\/g,'/').replace(/\\/[^\\/]*\$/, '');;
}
function dl_cmd(file) {
	dir = dirname(document.URL);
	return 'wget ' + dir + '/' + file;
}
</script>
</head>
<body>
<div class="container">

<div id="logo">
	<a href="http://txgen.tamu.edu/"><img src="/media/image/logo.png" alt="Texas A&amp;M AgriLife Research" /></a><br />
	<div id="department"><a href="http://www.txgen.tamu.edu/">Genomics and Bioinformatics Services</a></div>
</div>
<ul id="properties">
	<li>Run number: $run_id</li>
	<li>Library: $lib_name</li>
	<li>TimeStampName: $stamp_name</li>
	<li>Date: $run_start</li>
	<li>Sequencer ID: 54092</li>
</ul>
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
