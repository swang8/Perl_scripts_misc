#!/usr/bin/perl -w
use strict;
use lib "/home/shichen.wang/perl5/lib/perl5";
use Bio::DB::Fasta;
use Parallel::ForkManager;
use File::Basename;
use Storable;
#use CGI;
#use CGI::Carp qw(fatalsToBrowser);
#use JSON;

## $CGI::POST_MAX = 1024 * 50000; ## maximum 50Mb
my $safe_filename_characters = "a-zA-Z0-9_.";
my $upload_dir = "/tmp";
my $start = localtime(time);
## my $q = new CGI;
## print $q->header(-type => "application/json", -charset => "utf-8");
## my $len = $q->param('selection');
## my $file = get_file($q);
## if ($file){
##   my @status = check_barcodes($file, $len);
##   my $json = to_json(\@status);
##   print $json;
## }
## exit;
##
#

=head1 DESCRIPTION

Output:
 1)    A list (Stats), containing
 The name of the Test file
 The number of barcodes in Test file
 The length of the barcodes in Test files
 How many barcodes did have hits with 0 mismatches
 How many barcodes did have hits with 1 mismatch
 How many barcodes did have hits with 2 mismatches
 How many barcodes did have hits with 3 mismatches

  
  2)    A list (Test Summary for Targets) describing how many hits with 0, 1, 2, 3 mismatches were found for each target file, against the whole test file. The header should describe
  a.     The columns should be:
  After the header there should be a list
  b.     Target File name (name of the target file)
  Number of sequences in target file
  Barcode Length in target file
  Number of Hits with 0 mismatches
  Number of Hits with 1 mismatch
  Number of Hits with 2 mismatches
  Number of Hits with 3 mismatches

   
   3)    Another list (all hits list) describing the hits. There should be a row for each hit. The columns should be:
   Barcode Name (from Test file)
   Barcode Sequence (from Test file)
   Target File name (name of the target file)
   Target Barcode Name (from Target file)
   Target Barcode Sequence (from Target file)
   Number of mismatches

    
    4)    Another list (Test hits) describing the hits for each Barcode in the Test file. There should be a row for each barcode in the Test file. The columns should be:
    Barcode Name (from Test file)
    Barcode Sequence (from Test file)
    Number of Hits with 0 mismatches
    Number of Hits with 1 mismatch
    Number of Hits with 2 mismatches
    Number of Hits with 3 mismatches
=cut

my $sUsage = qq(
perl $0  <test_barcode_file> <target_barcode_file> <target_barcode_file> ...
Note: input files can be in FASTA or csv.
  >barcode_1
  ATCGATGCTA
  ...
or
  barcode_1,ATCGATGCTA
  ...
);


die $sUsage unless @ARGV >= 2;
my ($test_file, @target_files) = @ARGV;

my %test_barcodes = read_barcode_files($test_file);
my %target_barcodes = read_barcode_files(@target_files);

my @test_barcodes_flat = map{keys %{$test_barcodes{$_}}}keys %test_barcodes;
my @target_barcodes_flat = map{keys %{$target_barcodes{$_}}}keys %target_barcodes;

my %dist = calculate_distance([@test_barcodes_flat], [@target_barcodes_flat]);

# output a distance matrix for each comparison
foreach my $test_file (keys %test_barcodes){
   my @t_barcodes = keys %{$test_barcodes{$test_file}};
   foreach my $target_file (keys %target_barcodes){
       my @g_barcodes = keys %{$target_barcodes{$target_file}};
       my $output_file = basename($test_file) . "_" . basename($target_file) . "_mismatch_matrix.csv";
       open(OUT, ">$output_file") or die $!;
       print OUT join(",", "", "", map{$target_barcodes{$target_file}{$_}}@g_barcodes), "\n";
       print OUT join(",", "", "", @g_barcodes), "\n";
       foreach my $tb (@t_barcodes){
           my @p = map{$dist{join(" ", sort{$a cmp $b}($tb, $_))} }@g_barcodes;
           print OUT join(",",  $test_barcodes{$test_file}{$tb}, $tb, @p), "\n";
       }
   }
}

# check the test file
foreach my $f(keys %test_barcodes) {
    my @barcodes = keys %{$test_barcodes{$f}};
    my ($num, $bp_summary) = summary(@barcodes);
    my $out = basename($f) . "_stat.csv";
    open(OUT, ">$out") or die $!;
    print OUT "Test: ", $f, "\n";
    print OUT "Total number, ", $num, "\n";
    print OUT "legnth of barcodes, ", $bp_summary,"\n";

    foreach my $tf (keys %target_barcodes){
        my @t_barcodes = keys %{$target_barcodes{$tf}};
        my ($count_href, $sum_arrref) = &count_missmatch(\@barcodes, \@t_barcodes, \%dist);

        print OUT "target: ", $tf, "\n";
        print OUT join(",", qw(mismatch Count)),"\n";
        map{print OUT  join(",", $_, $sum_arrref->[$_]), "\n"}0..3;

        print OUT join(",", "Barcode_name", "barcode", map{$_."_missmatches"}0..3), "\n";
        map{print OUT join(",", $test_barcodes{$f}{$_}, $_, @{$count_href->{$_}}), "\n" }keys %{$count_href};
    }
    close OUT;
}
# target files;
foreach my $tf (keys %target_barcodes){
    my @barcodes = keys %{$target_barcodes{$tf}};
    my ($num, $bp_summary) = summary(@barcodes);
    my $out = basename($tf) . "_stat.csv";
    open(OUT, ">$out") or die $!;
    print OUT "Total number, ", $num, "\n";
    print OUT "legnth of barcodes, ", $bp_summary,"\n";
    
    foreach my $test (keys %test_barcodes){
      my @t_barcodes = keys %{$test_barcodes{$test}};
      my ($count_href, $sum_arrref) = &count_missmatch(\@barcodes, \@t_barcodes, \%dist);
      #output

      print OUT join(",", qw(mismatch Count)),"\n";
      map{print OUT join(",", $_, $sum_arrref->[$_]), "\n"}0..3;

      print OUT join(",", "Barcode_name", "barcode", map{$_."_missmatches"}0..3), "\n";
      map{print OUT join(",", $target_barcodes{$tf}{$_}, $_, @{$count_href->{$_}}), "\n" }keys %{$count_href};
    }
    close OUT;
}


#####
sub count_missmatch {
  my ($test, $query, $dist_ref) = @_;
  my %count;
  my $missmatch_num = 3; # only record barcodes that have missmatches less than $missmatch_num;
  foreach my $test_b (@$test){
    map{$count{$test_b}->[$_]=0}0..$missmatch_num;
    foreach my $target_b (@$query){
      my $d = $dist_ref->{join(" ", sort{$a cmp $b}($test_b, $target_b))};
      die "No distance for $test_b, $target_b!" unless defined $d;
      if($d <= $missmatch_num){$count{$test_b}->[$d] ++}
    }      
  }
  my @arr=();
  map{$arr[$_] = 0}0..$missmatch_num;
  foreach my $p (values %count){
    foreach my $ind (0..$missmatch_num){
        if($p->[$ind] != 0){$arr[$ind]++; last}
    }    
  }
  return (\%count, \@arr);
}

sub summary {
    my @arr = @_; 
    my $n_barcode = scalar @arr;
    my %len = ();
    map{$len{(length $_)."bp"}++  }@arr;
    my @p = map{$_ . "_".$len{$_}} sort{$a cmp $b} keys %len;
    return($n_barcode, join(";", @p))
}

sub read_barcode_files {
  my @files = @_;
  my %return;
  foreach my $f (@files){
    open (my $F, $f) or die $!;
    my $id;
    my $line=0;
    my $is_fasta = 0;
    while(<$F>){
      $line++; if($line==1){$is_fasta = 1 if /^>/}
      if ($is_fasta){
          if (/>(\S+)/){$id=$1; next};    
          chomp;
          my @p = split /\s+/,$_; 
          if(exists $return{$f}{$_}){print STDERR "Duplicated barcode $_; Exit!\n"; }
          $return{$f}{$_} = $id; # assume single barcode for now
      }
      else{
          chomp;
          s/\s//g;
          my @p = split /,/, $_; 
          if(exists $return{$f}{$p[1]}){print STDERR "Duplicated barcode $_; Exit!\n"; }
          $return{$f}{$p[1]} = $p[0]
      }
    }
    close $F;
  }
  return %return;
}

sub check_barcodes{
  my $cutoff = 5;
  my %h;
  my @arr = @_; # barcodes array
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
        print STDERR $id, "\t", $dist{$id}, "\n";
        if (! exists $dist{$id}){die "$id not in \%dist\n"}
        if($dist{$id} < $cutoff){
            push @conf, join("_", @{$arr[$ind2]}, $dist{$id});
        }
      }else{
        my $id0 = join(" ", sort{$a cmp $b}($ba[0], $bb[0]) );    
        my $id1 = join(" ", sort{$a cmp $b}($ba[1], $bb[1]) );
        print STDERR $id0, "\t", $dist{$id0}, "\n";
        print STDERR $id1, "\t", $dist{$id1}, "\n";
        if($dist{$id0} < $cutoff and $dist{$id1} < $cutoff){
            push @conf, join("_", @{$arr[$ind2]}, $dist{$id0}, $dist{$id1});
        }
      }
    }
    push @conflict, {"barcode"=>join("_", @{$arr[$ind1]}), "potential_conflict"=>join(",", @conf)} if @conf > 0;
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
