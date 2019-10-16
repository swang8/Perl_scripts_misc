perl -MFile::Basename -e '
@fs=<*.pdf>; 
$proj = shift;
@ps=@ARGV;
$ps_str = join("\n", (map{"<li>"."<a href=\"$_\">" . $_ . "</a>". "</li>"}@ps));
$ps_str = "<ul>" . $ps_str . "</ul>";

map{push @enz, $1 if /\.gz_(\S+)\.pdf/}@fs; 
$col_width = 12 / (scalar @ps);
$col_md = "col-md-".$col_width;
$tm = localtime(time);

# print header
print qq(
<html lang="en">
<head>
  <title>In Silico Digestion</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
  <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
</head>
<body>
<div class="container">
  <div class="row">
        <div id="logo" class="col-xs-3">
                <a href="http://agriliferesearch.tamu.edu/"><img src="/media/image/logo.png" alt="Texas A&amp;M AgriLife Research" class="img-responsive"/></a>
        </div>

        <div id="logo" class="col-xs-9">
                <a href="http://txgen.tamu.edu/"><img src="/media/image/txgen_logo2.png" alt="Genomics and Bioinformatics Services" style="width:40%;" class="img-responsive pull-right"/></a>
        </div>
  </div>

<h3>In Silico digestion test for project <code>$proj</code></h3>
<p>Files used for in silico digestion:</p>
$ps_str
<h4>$tm</h4>
<hr>
);
# generate a table for enzymes
# @enz = sort{@pa=split /_/, $a; @pb=split /_/, $b; scalar @pa <=> scalar @pb or $a cmp $b}@enz;
@enz=sort{$a cmp $b}@enz;
$num_per_row = 10;
$nrow = int((scalar @enz)/$num_per_row);
$nrow++ if (scalar @enz) % $num_per_row;
print "<table class=\"table\">\n";
foreach $nr (1..$nrow){
print "<tr>";
$start = ($nr-1) * $num_per_row;
$end = $start + $num_per_row - 1;
$end = $#enz if $end > $#enz;
map{print "<td><a href=\"\#$enz[$_]\">$enz[$_]</a></td>"}$start .. $end;
print "</tr>";
}
print "</table>\n<hr>\n";

# generate thumbnail
$missing="/media/image/nocut.png";
foreach $e(@enz){
  print "<h3 id=\"$e\">$e</h3>\n"; 
  print "<div class=\"row\">\n"; 
  foreach $p(@ps){
    $pdf = join("_", $p, $e) . ".pdf";
    $pdf=$missing unless -e $pdf;
    $img = join("_", $p, $e) . ".jpeg";
    $img=$missing unless -e $img;
    $caption=$p; $caption .="<br>The Enzyme is not cutting." unless -e join("_", $p, $e) . ".jpeg";
    print qq"<div class=\"$col_md\">\n
           <div class=\"thumbnail\">\n
           <a href=\"$pdf\" target=\"_blank\">\n
           <img src=\"$img\" style=\"width:100\%\">\n
           <div clas=\"caption\">\n
             <p>$caption</p>\n
           </div>\n
           </a>\n
           </div>\n
           </div>\n";
  } 
  print "</div>" 
}

# print ending tags
print qq(
</div>
</body>
</html>
)
'  $@
