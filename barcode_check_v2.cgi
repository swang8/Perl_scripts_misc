#!/usr/bin/perl -w
use strict;
use lib "/home/shichen.wang/perl5/lib/perl5";
use Bio::DB::Fasta;
use Parallel::ForkManager;
use File::Basename;
use Storable;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
$CGI::POST_MAX = 1024 * 50000; ## maximum 50Mb
my $safe_filename_characters = "a-zA-Z0-9_.";
my $upload_dir = "/tmp";
my $start = localtime(time);
my $q = new CGI;
print $q->header(-type => "application/json", -charset => "utf-8");
my $len = $q->param('selection');
$len += 1; 
my $file = get_file($q);
if ($file){
  my @status = check_barcodes($file, $len);
  my $json = to_json(\@status);
  print $json;
}
exit;
##
sub check_barcodes{
  my $f = shift;
  my $cutoff = shift;
  $cutoff = 3 unless $cutoff;
  open(IN, $f) or die $!;
  my %h;
  #read the file
  my @arr = ();
  while(<IN>){
    chomp;
    next unless /\S/;
    my @t = split /[,_\-\s\+]+/, uc($_);
    push @arr, [@t]
  }
  close IN;
  # checking
  my %dist = calculate_distance(@arr);
  my @conflict=();
  foreach my $ind1 (0 ..$#arr){
    my @ba = @{$arr[$ind1]};
    my $type_a = scalar @ba == 1?"single":"double";
    my @conf=();
    foreach my $ind2 ($ind1+1 .. $#arr){
      my @bb = @{$arr[$ind2]};
      my $type_b = scalar @bb == 1?"single":"double";
      if($type_a eq "single" or $type_b eq "single"){
        my $id = join(" ", sort{$a cmp $b}($ba[0], $bb[0]) );
        # print STDERR $id, "\t", $dist{$id}, "\n";
        if (! exists $dist{$id}){die "$id not in \%dist\n"}
        if($dist{$id} < $cutoff){
            push @conf, join("|", @{$arr[$ind2]}, $dist{$id});
        }
      }else{
        my $id0 = join(" ", sort{$a cmp $b}($ba[0], $bb[0]) );    
        my $id1 = join(" ", sort{$a cmp $b}($ba[1], $bb[1]) );
        #print STDERR $id0, "\t", $dist{$id0}, "\n";
        #print STDERR $id1, "\t", $dist{$id1}, "\n";
        if($dist{$id0} < $cutoff and $dist{$id1} < $cutoff){
            push @conf, join("|", join("_", @{$arr[$ind2]}), $dist{$id0}, $dist{$id1});
        }
      }
    }
    #push @conflict, {"barcode"=>join("_", @{$arr[$ind1]}), "potential_conflict"=>join(",", @conf)} if @conf > 0;
    map{my @p=split /\|/, $_;  my $href={"barcode"=>join("_", @{$arr[$ind1]}), "potential_conflict"=>$p[0], "zdistance_1" => $p[1]}; $href->{"zdistance_2"}=$p[2] if defined $p[2]; push @conflict, $href }@conf;
  }
  return @conflict;
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
          my $min_len = length $ka > length $kb?(length $kb):(length $ka);
          my $d = 0;
          foreach my $ind (0..$min_len-1){$d++ if substr($ka, $ind, 1) ne substr($kb, $ind, 1) }
          $dist{$id}=$d
      }    
  }
  return %dist;
}
sub unique{
  my @arr =@_;
  my %h = map{$_, 1 if /\S/}@arr;
  return keys %h;
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
   my $file = "/tmp/".random_string(8) .".csv";
   open(my $OUT, ">$file") or die $!;
   print $OUT $s, "\n";
   close $OUT;
   print STDERR $file, "\n";
   return $file;
}

sub random_string {
   my $len = shift;
   my @arr = ("A".."Z", "a" .. "z", "_", "-", 0..9);
   my $str = "";
   map{$str  .=  $arr[int(rand(scalar @arr))]}1..$len;
   return $str . time();
 }
