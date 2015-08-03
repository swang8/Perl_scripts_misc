#!/usr/bin/perl -w
use strict;

# http://www.ars-grin.gov/cgi-bin/npgs/acc/list_post.pl?lopi=10000&hipi=626309&lono=&hino=&plantid=&pedigree=&taxon=&family=&cname=&country=&state=&site=ALL%20-%20All%20Repositories&acimpt=Any%20Status&uniform=Any%20Status&recent=anytime&pyears=1&received=&records=1000

my $start = 10000; 
my $end = 700000;
my $step = 1000;

print join("\t", map{"\"".$_."\""}("ACNO", "Accession", "Location", "Latitude", "Longitude")), "\n";
while($start < $end){ 
  my $stop = $start + $step - 1;
  $stop = $end if $stop > $end;
  my $out = "pi.tmp";
  unlink($out) if -e $out;
  my $cmd = "wget -O $out \"http://www.ars-grin.gov/cgi-bin/npgs/acc/list_post.pl?lopi=${start}&hipi=${stop}&lono=&hino=&plantid=&pedigree=&taxon=&family=&cname=&country=&state=&site=ALL%20-%20All%20Repositories&acimpt=Any%20Status&uniform=Any%20Status&recent=anytime&pyears=1&received=&records=${step}\"";
  die if system($cmd);
  &parse_html($out);
  $start += $step;
}

## 
sub parse_html{
  my $file = shift;
  open(IN, $file) or die $!;
  while(<IN>){
    if(/^\<DT\>/){
        print STDERR $_; 
	my $pi = $1 if /PI\s+(\d+)\</;
	my $name = $1 if /\<DD\>\<i\>(.*)\<\/i\>/;
	$name =~ s/\<\S+?\>//g;
	my $location = $1 if /from\s+(.*)\<p\>/;
	my $link=$1 if /HREF=(\S+?)\>/;
	my ($lat, $lon) = get_gis($link);
	print join("\t", map{"\"".$_."\""}("PI".$pi, $name, $location, $lat, $lon)), "\n";
    }
  }
  close IN;
} 

sub get_gis{
  my $link = shift;
  my $cmd = "wget -O gis.tmp \"" . $link . "\"";
  die if system($cmd);
  open(my $IN, "gis.tmp") or die;
  my ($latitude, $longitude) = ("NA", "NA");
  while(<$IN>){
    if(/Latitude/){
        print STDERR $_;
      if(/Latitude:.*?\((\S+)\)\,\s+Longitude:.*?\((\S+)\)/){
        ($latitude, $longitude) = ($1, $2);
        if($latitude eq "NA"){print $_, $latitude, "\n", $longitude, "\n"}
        last;
      }
    }
  }
  close $IN;
  return($latitude, $longitude);
}
