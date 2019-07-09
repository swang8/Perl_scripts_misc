#!/usr/bin/perl -w
use strict;
use LWP::Simple;
use Getopt::Long;
use lib "/home/shichen.wang/perl5/lib/perl5";
use JSON;
use JSON::Parse 'parse_json';
use HTML::Make;
use File::Copy;
use File::Basename;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

$CGI::POST_MAX = 1024 * 50000; ## maximum 50Mb
my $safe_filename_characters = "a-zA-Z0-9_.";
my $upload_dir = "/tmp";
my $start = localtime(time);
my $q = new CGI;
print $q->header(-type => "application/json", -charset => "utf-8");
my $len = $q->param('selection');
my $check_plate_position = $q->param('check');
print STDERR "check_plate_position: ", $check_plate_position?1:0, "\n";
$len += 1;
my $lib_csv = get_file($q);
    
my %barcode_source_urls = (
NEB_CDI  => "https://raw.githubusercontent.com/swang8/barcodes/master/NEB_NEXT_CDI_Combined.csv",
PERKIN_HT_S1 => "https://raw.githubusercontent.com/swang8/barcodes/master/PerkinElmer_NextFlex_HT_SI.csv",
PERKIN_UDI => "https://raw.githubusercontent.com/swang8/barcodes/master/PerkinElmer_NextFlex_UDI.csv",
PERKIN_UDI_4K => "https://raw.githubusercontent.com/swang8/barcodes/master/PerkinElmer_NextFlex_UDI_4000.csv",
TXGEN_DULIG => "https://raw.githubusercontent.com/swang8/barcodes/master/TxGen_DuLig_CDI_Combined.csv"
);

if ($lib_csv){
  my @status = compatibility_check($lib_csv);
  my $json = to_json(\@status);
  print $json;
}
exit;

sub compatibility_check {
    my $lib_csv = shift;
    my %lib_info = read_csv($lib_csv); 
    print STDERR join(":", keys %lib_info), "\n";

    # check header in the lib csv
    # Sample	Project	Barcode_number	Barcode_id	i7	i5	Barcode_source
    my @header_required = qw(Sample	Project	Barcode_number	Barcode_id	i7	i5	Barcode_source);
    push @header_required, "Plate_position" if $check_plate_position; 
    @header_required = map{uc $_} @header_required;
    my @missed_header = ();
    map{
        push @missed_header, $_ unless exists $lib_info{$_}
    }map{uc $_}@header_required;
    print STDERR join("-", keys %lib_info), "\n" if exists $ENV{DEBUG};
    print STDERR join("+", @header_required), "\n" if exists $ENV{DEBUG};

    $lib_info{"Barcode_source"} = [map{uc $_} @{$lib_info{"Barcode_source"} }];
    my @projects = unique(@{$lib_info{$header_required[1]}});

    # output html file
    my $output = "/tmp/" . join("_", @projects) . "_". random_string() . ".html";
    print STDERR "output :  ", $output, "\n" if exists $ENV{DEBUG};
    open(my $OUT, ">", $output) or die $!;
    print_header($OUT);
    if(@missed_header){ print STDERR  "<h2>Error :  some of the headers are missing : ", join(",", @missed_header), "</h2>\n" ; }
    if(@missed_header){ 
        print $OUT "<h2>Error :  some of the headers are missing : ", join(",", @missed_header), "</h2>\n" ;
        close $OUT;
        my $new_file =  "/data3/Downloads/check_reports/" . basename($output);
        my $report_url = "http://download.txgen.tamu.edu/check_reports/".basename($output);
        copy($output, $new_file) ; #or print STDERR "Copy failed  :   $new_file can not be made.\n";
        return ({"report"=>$report_url, "errors"=> 1})
    }
    
    my $lib_header_as_key = 4; # the 4th column from the required header
    my %lib_info_zip = zip($lib_header_as_key, @lib_info{@header_required}); # 4 indicate Barcode_id will be the key for hash

    # load the barcode csv files
    my %barcodes = load_barcodes();
    my %barcodes_zip;
    map{
        my %tmp = %{$barcodes{$_}};
        $barcodes_zip{$_} = {zip(2, @tmp{map{uc}qw(Number	Id	i7	i5 Coordinate)})};
    }keys %barcodes;

    # Check
    # a)	Will check for consistency Id vs Name vs Position in Plate
    print $OUT "<h2>1. Check for consistency Id vs Name vs Position in Plate </h2>\n";
    ## ids
    my @tobe_checked;
    my ($num_error, $i7_error, $i5_error, $plate_pos_error) = (0, 0, 0, 0);
    my @check_results;
    foreach my $k (@{$lib_info{$header_required[$lib_header_as_key-1]}}){
        print STDERR "\$k :  ", $k, "\n" if exists $ENV{DEBUG};
        my @arr = @{$lib_info_zip{$k}};
        print STDERR join("-", keys %{$barcodes_zip{$arr[6]}}) if exists $ENV{DEBUG};
        my @results;
        $arr[6] = uc $arr[6]; # uppcase
        if (not exists $barcode_source_urls{$arr[6]}) {
            #print STDERR "Error :  $arr[6] is not one of the (neb_CDI perkin_HT_S1 perkin_UDI perkin_UDI_4K txgen_dulig)!" if exists $ENV{DEBUG}; 
            push @check_results, "<a style=\"background:salmon; color:blue\">Error :  $arr[6] is not one of the (neb_CDI perkin_HT_S1 perkin_UDI perkin_UDI_4K txgen_dulig)!</a>";
        }
        print STDERR "! ", $arr[2] , "\t", $barcodes_zip{$arr[6]}->{$k}->[0], "\n" if exists $ENV{DEBUG};
        print STDERR "! ", $arr[4] , "\t", $barcodes_zip{$arr[6]}->{$k}->[2], "\n" if exists $ENV{DEBUG};
        print STDERR "! ", $arr[5] , "\t", $barcodes_zip{$arr[6]}->{$k}->[3], "\n" if exists $ENV{DEBUG};
        if ($arr[2] == $barcodes_zip{$arr[6]}->{$k}->[0]){push @results, "Index number matching"}else{push @results, "<a style=\"color:red\">Index number NOT matching</a>"; $num_error++}
        if ($arr[4] eq $barcodes_zip{$arr[6]}->{$k}->[2]){push @results, "i7 matching"}else{push @results, "<a style=\"color:red\">i7 NOT matching</a>"; $i7_error++}
        if ($barcodes_zip{$arr[6]}->{$k}->[3] ){
            if ($arr[5] eq $barcodes_zip{$arr[6]}->{$k}->[3]){push @results, "i5 matching"}else{push @results, "<a style=\"color:red\">i5 NOT matching </a>"; $i5_error++}
        }
        else{
            push @results, "i5 empty"    
        }
        # check plate position
        if ($check_plate_position ){
            if ($arr[7] eq $barcodes_zip{$arr[6]}->{$k}->[-1]){push @results, "Plate position is matching"}else{push @results, "<a style=\"color:red\">Plate position is NOT matching: $arr[7] vs $barcodes_zip{$arr[6]}->{$k}->[-1])</a> "; $plate_pos_error++;}    
        }

        push @check_results,  join(", ", @arr, @results);
        if ($arr[5]){
                push @tobe_checked, [@arr[0, 3], uc $arr[4], uc $arr[5]];
        }
        else {
            push @tobe_checked, [@arr[0, 3], uc $arr[4]];    
        }
    }
# qw(Sample Project Barcode_number  Barcode_id  i7  i5  Barcode_source);
    print $OUT "<div id=\"stats\">";
    print $OUT  "Total samples: ", scalar @{$lib_info{$header_required[0]}}, "<br>\n";
    print $OUT  "Projects: total ", scalar unique(@{$lib_info{$header_required[1]}}),": ", join(", ", unique(@{$lib_info{$header_required[1]}})), "<br>\n";
    print $OUT  "Total unique barcodes: ", scalar unique(@{$lib_info{$header_required[3]}}), "<br>\n";
    print $OUT  "From barcode sources: ", join(", ", map{"<a target= \"_blank\" href=\"$barcode_source_urls{$_}\">".$_."</a>" } (map{$_ if(exists $barcode_source_urls{$_})}unique(map{uc}@{$lib_info{$header_required[6]}})) ), "<br>\n";
    print $OUT "</div>";
    print $OUT "<br>";
    print $OUT "<div>Error count: <li>Index number error :  ",  add_color($num_error), "</li><li> i7 seq error :  ", add_color($i7_error), "</li><li>i5 seq error :  ", add_color($i5_error), "</li> <li> Plate position error: ", add_color($plate_pos_error), "</li> </div>\n";
    print $OUT "<p><h4>Error list : </h4></p>\n";
    print $OUT "<pre>\n";
    print $OUT join("\n", grep{/NOT/}@check_results), "\n";
    print $OUT "</pre>\n";

    print $OUT "<p><h4>Full checking list : </h4></p>\n";
    print $OUT "<pre>\n";
    print $OUT join("\n", @check_results), "\n";
    print $OUT "</pre>\n";

    # b)	Will check for barcode compatibility (with extension to 12+8 optional)
    print $OUT "<hr><h2>2. Barcode conflict checking</h2>\n";
    my @conflicts = check_barcodes(\@tobe_checked, $len);
    my @barcode_conflict_pair_count = count_barcode_conflict($len, @conflicts);
    print $OUT "<strong>Barcode conflict pair counting table</strong>";
    my $count_table = to_table(["Number_Mismatches", "Number_pairs"], map{[$_, $barcode_conflict_pair_count[$_]] }0..$#barcode_conflict_pair_count);
    print $OUT $count_table, "\n";

    if (@conflicts){
        print $OUT "<h4><a style=\"color : red\">There are conflicts detected!!" , (scalar @conflicts > 10?" A lot!" : ""),   "</a><h4><br>\n";
        my $json = to_json([@conflicts]);
        print STDERR $json, "\n" if exists $ENV{DEBUG};
        my $p = parse_json($json);
        my $html = json_to_html($p);
        my $txt = $html->text();
        $txt =~ s/\<table/\<table class=\"table\"/g;
        print $OUT "<div style=\"width :  100%; height :  600px; overflow-y :  scroll; background-color : \#eee\">";
        print $OUT $txt;
        print $OUT "</div>"
    }
    else {
        print $OUT "<a style=\"color : blue\">Barcodes are compatible!</a>"
    }

    print $OUT "<hr>\n";
    print $OUT "<h3>The original input file (with conflicted ones colored in red) :</h3>";
    print $OUT "<pre id=\"original\" style=\"width :  100%; height :  600px; overflow-y :  scroll; background-color : \#eee\"  >";
    my %conflict_barcodes = map{my $id=(split / : /, $_->{barcode})[1]; ($id, 1) }@conflicts;
    open (ORI, $lib_csv) or die $!;
    #qw(Sample Project Barcode_number  Barcode_id  i7  i5  Barcode_source);
    my $bid_index;
    while(<ORI>){
      chomp;
      my @t = split /,/, $_;
      if($. == 1){map{$bid_index = $_ if $t[$_] eq "Barcode_id"} 0..$#t;}
      $t[$bid_index]=~s/\s//g;
      if (exists $conflict_barcodes{$t[$bid_index]}){print $OUT "<a style=\"color:red\">", $_, "</a>\n"}
      else{print $OUT $_, "\n"}
    }
    print $OUT "</pre>";
    print $OUT "<hr>\n";
    # c)	Will generate report to download
    my $report_url = "http://download.txgen.tamu.edu/check_reports/".basename($output);
    print $OUT "Report :  ", "<a target=\"_blank\" href=\"$report_url\"> $report_url </a>";
    print_end($OUT);
    close $OUT;

    my $new_file =  "/data3/Downloads/check_reports/" . basename($output);
    copy($output, $new_file) ; #or print STDERR "Copy failed :  $new_file can not be made.\n";
    copy($output, "./".basename($output)) ; #or print STDERR "Copy failed :  $output can not be made.\n";
    print STDERR "Report :  ", "http://download.txgen.tamu.edu/check_reports/".basename($output);

    my $any_error = 0; $any_error = 1 if $num_error or $i7_error or $i5_error or $plate_pos_error or scalar @conflicts > 0;
    return ({"report"=>$report_url, "errors"=> $any_error})
}

######
sub load_barcodes {
    my @sources = keys %barcode_source_urls;
    my %return;
    map{
        my $s = $_;
        print STDERR "Source :  ", $s, "\n" if exists $ENV{DEBUG};
        my %info = read_csv($barcode_source_urls{$s});
        $return{$s} = \%info;
    } @sources;
    return %return;
}

sub get_barcode_file {
    my $url = shift;
    my $file = (split /\//, $url)[-1];
    getstore($url, "/tmp/" . $file);
}

sub read_csv {
    my $f = shift;
    print STDERR "CSV :  ", $f, "\n" if exists $ENV{DEBUG};
    my $IN;
    if ($f=~/^http/){open($IN, "wget -O- -nv $f |") or die $!}
    else{open($IN, $f) or die "$f is not readable!\n";}
    
    my %return;
    my @header;
    my $line = 0;
    while(<$IN>){
        next if /\#/;
        chomp;
        next unless /\S/;
        $line++;
        s/\s+//g;
        s/\,+$//;
        my @t = split /\,/, $_;
        if ($line == 1){@header = map{uc}@t;  print STDERR "Header :  ", join("  :  ", @header), "\n" if exists $ENV{DEBUG}; next}
        map{
            push @{$return{$header[$_]}}, (defined $t[$_]?$t[$_]:"")
        }0..$#header;
    }
    close $IN;
    print STDERR join("-", keys %return), "\n" if exists $ENV{DEBUG};
    return %return;
}

sub zip {
    my $k = shift;
    my @arr = @_;
    map{print STDERR ref $_, "\n" if exists $ENV{DEBUG}}@arr;
    my @len = map{scalar @$_; }@arr;
    my $max_len = max(@len);
    my %return;
    map{
        my $index = $_;
        my @z = ();
        foreach my $ref (0 .. $#arr){
            if ($index > $len[$ref] - 1) {$index = $len[$ref] - $index}
            push @z, $arr[$ref]->[$index]
        }
        if (exists $return{$z[$k-1]}){print STDERR "Duplicated barcode ID ($z[$k-1]) detected!!\n\n";}
        else{$return{$z[$k-1]} = [@z];}
    } 0 .. $max_len - 1;

    return %return;
}

sub max {
    my @arr = @_;
    my $m = shift @arr;
    map{$m = $_ if $_ > $m}@arr;
    return $m;
}

sub random_string {
    my $l = shift || 12;
    my @letters=('a'..'z', 'A'..'Z', 0..9);
    my $return="";
    map{$return .= $letters[int(rand(scalar @letters))]}1..$l;
    return $return
}

sub check_barcodes{
  my $arr_ref = shift; # [sample, name, seq1, seq2]
  my $cutoff = shift;
  $cutoff = 3 unless $cutoff;
  my @arr = map{my @p = @$_; [@p[2..$#p]]} @$arr_ref;
  # checking
  my %dist = calculate_distance(@arr);
  my @conflict=();
  foreach my $ind1 (0 ..$#arr){
    my @ba = @{$arr[$ind1]};
    my $type_a = scalar @ba == 1?"single" : "double";
    my @conf=();
    foreach my $ind2 ($ind1+1 .. $#arr){
      my @bb = @{$arr[$ind2]};
      my $type_b = scalar @bb == 1?"single" : "double";
      if($type_a eq "single" or $type_b eq "single"){
        my $id = join(" ", sort{$a cmp $b}($ba[0], $bb[0]) );
        # print STDERR $id, "\t", $dist{$id}, "\n" if exists $ENV{DEBUG};
        if (! exists $dist{$id}){die "$id not in \%dist\n"}
        if($dist{$id} < $cutoff){
            push @conf, join(" : ", $arr_ref->[$ind2][0], $arr_ref->[$ind2][1],@{$arr[$ind2]}, $dist{$id});
        }
      }else{
        my $id0 = join(" ", sort{$a cmp $b}($ba[0], $bb[0]) );
        my $id1 = join(" ", sort{$a cmp $b}($ba[1], $bb[1]) );
        #print STDERR $id0, "\t", $dist{$id0}, "\n" if exists $ENV{DEBUG};
        #print STDERR $id1, "\t", $dist{$id1}, "\n" if exists $ENV{DEBUG};
        if($dist{$id0} < $cutoff and $dist{$id1} < $cutoff){
            push @conf, join(" : ",$arr_ref->[$ind2][0],$arr_ref->[$ind2][1],  @{$arr[$ind2]}, $dist{$id0}, $dist{$id1});
        }
      }
    }
    #push @conflict, {"barcode"=>join(" : ", $arr_ref->[$ind1][0],$arr_ref->[$ind1][1], @{$arr[$ind1]}), "potential_conflict"=>join(", ", @conf)} if @conf > 0;
    map{my @p = split / : /, $_; if(scalar @p==6){@p=(@p[-2,-1])}else{@p=($p[-1], " ")} push @conflict, {"barcode" => join(" : ", $arr_ref->[$ind1][0],$arr_ref->[$ind1][1], @{$arr[$ind1]}), "conflict"=> $_, "mismatches" => join(" : ", @p)  } }@conf; 
  }
  return @conflict;
}

sub count_barcode_conflict {
  my $cutoff = shift;
  my @conflicts = @_;
  my @return = map{0} 0.. $cutoff-1;
  foreach my $href (@conflicts) {
    map{
      my @p = split / : /, $_; 
      $return[$p[-1]]++
    }(split /,/, $href->{"conflict"});     
  }
  return @return;
}

sub calculate_distance{
  my @arr = @_;
  my @flat = map{@$_}@arr;
  @flat = unique(@flat);
  my %dist = ();
  foreach my $ka (@flat){
      foreach my $kb (@flat){
          my $id = join(" ", sort{$a cmp $b}($ka, $kb));
          next if exists $dist{$id};
          if($ka eq $kb){$dist{$id} = 0; next}
          my $min_len = length $ka > length $kb?(length $kb) : (length $ka);
          my $d = 0;
          foreach my $ind (0..$min_len-1){$d++ if substr($ka, $ind, 1) ne substr($kb, $ind, 1) }
          $dist{$id}=$d
      }
  }
  return %dist;
}

sub unique{
  my @arr =@_;
  my %h;
  %h = map{$_, 1 if /\S/}@arr;
  return keys %h;
}

sub json_to_html
{
    my ($input) = @_;
    my $element;
    if (ref $input eq 'ARRAY') {
        $element = HTML::Make->new ('ol');
        for my $k (@$input) {
            my $li = $element->push ('li');
            $li->push (json_to_html ($k));
        }
    }
    elsif (ref $input eq 'HASH') {
        $element = HTML::Make->new ('table');
        for my $k (sort keys %$input) {
            my $tr = $element->push ('tr');
            $tr->push ('th', text => $k);
            my $td = $tr->push ('td');
            $td->push (json_to_html ($input->{$k}));
        }
    }
    else {
        $element = HTML::Make->new ('span', text => $input);
    }
    return $element;
}

sub print_header {
    my $fh = shift;
    my $h = qq(
<html lang="en">
<head>
  <title></title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
  <style>
  pre {
    height :  auto;
    max-height :  500px;
    overflow :  auto;
    background-color :  #eeeeee;
    word-break :  normal !important;
    word-wrap :  normal !important;
    white-space :  pre !important;
}

table {
        display :  block;
        overflow-x :  auto;
        white-space :  nowrap;
    }

</style>
</head>
<body>
<div class="container">
  <div class="row">
        <div id="logo" class="col-xs-3">
                <a href="http://agriliferesearch.tamu.edu/"><img src="http://download.txgen.tamu.edu/media/image/logo.png" alt="Texas A&amp;M AgriLife Research" class="img-responsive"/></a>
        </div>

        <div id="logo" class="col-xs-9">
                <a href="http://txgen.tamu.edu/"><img src="http://download.txgen.tamu.edu/media/image/txgen_logo2.png" alt="Genomics and Bioinformatics Services" style="width : 30%;" class="img-responsive pull-right"/></a>
        </div>
  </div>
<hr>    
    );
    print $fh $h, "\n";
}

sub print_end {
    my $fh = shift;
    my $e =  qq(
</div>
<hr>
</body>
</html>
    );
    print $fh $e;
}
sub add_color {
    my $n = shift;
    my $res;
    if ($n > 0){$res = "<a style=\"color : red\">" . $n . "</a>"}
    else{$res = "<a style=\"color : green\">" . $n . "</a>"}
    return $res;
}

sub get_file {
  my $q = shift;
  my $file;
  if($q->param("SEQUENCE") =~ /\S/) {
     $file = create_tmp_file($q->param("SEQUENCE"));
     return $file;
  }
  elsif($q->param("SEQFILE")){
    my $filename = $q->param("SEQFILE");
    print STDERR $filename, "\n";
    my ( $name, $path, $extension ) = fileparse ( $filename, '..*' );
    $filename = $name . $extension;
    $filename =~ tr/ /_/;
    $filename =~ s/[^$safe_filename_characters]//g;

    if ( $filename =~ /^([$safe_filename_characters]+)$/ )
    {
     $filename = $1;
    }
    else
    {
     die "Filename contains invalid characters";
    }

    #my $upload_filehandle = $q->upload("SEQFILE");

    $file = "$upload_dir/$filename" . random_string(8).  time() . ".csv";

    #open ( UPLOADFILE, ">$file" ) or die "$!";
    my $tfile = $q->tmpFileName($q->param('SEQFILE'));
    system("cp  $tfile $file");
    #while ( <$upload_filehandle> )
    #{
    #  print UPLOADFILE $_;
    #}
    #
    #close UPLOADFILE;
    return $file;
  }
  else{
    #&show_html();
    #print $q->end_html();
    #exit 1;
    return;
  }
}
sub create_tmp_file {
      my $s = shift;
      $s =~ s///g;
      my $file = "/tmp/".random_string(8) .".csv";
      open(my $OUT, ">$file") or die $!;
      print $OUT $s, "\n";
      close $OUT;
      #print STDERR $file, "\n";
      return $file;
}

sub to_table {
  my $header = shift;
  my @arr = @_;
  my $return = "<table class=\"table table-stripped\">\n";
  my @trs;
  my $ths = th(@$header);
  push @trs, "<tr>".$ths."</tr>";

  foreach (@arr){
    my @p = @$_;
    my $tds = td(@p);
    push @trs, "<tr>" . $tds . "</tr>";
  }
  $return .= join("\n", @trs);
  $return .= "\n</table>\n";
  return $return;
}

sub td {
  my @arr = @_;
  my @tds = map{"<td>".$_."</td>"}@arr;
  return join("\n", @tds);
}

sub th {
  my @arr = @_;    
  my @ths = map{"<th>".$_."</th>"}@arr;
  return join("\n", @ths);
}
