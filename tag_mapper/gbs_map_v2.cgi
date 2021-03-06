#!/usr/bin/perl -w
use strict;
use lib "/home/shichen.wang/perl5/lib/perl5";
use Parallel::ForkManager;
use File::Basename;
use Storable;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
my $gfClient = "/home/shichen.wang/bin/i686/gfClient ";

$CGI::POST_MAX = 1024 * 50000; ## maximum 50Mb
my $safe_filename_characters = "a-zA-Z0-9_.";
my $upload_dir = "/tmp";
my $start = localtime(time);
my $q = new CGI;
#print $q->header('application/json');
print $q->header(-type => "application/json", -charset => "utf-8");
#print $q->start_html();

my $file = get_file($q);
if ($file){
  my %status = run_the_job($file);
  $status{"0.submit_time"} = $start . " Job submitted.<br>";
  my $json = to_json(\%status);
  print $json;
}
#print $q->end_html();
exit;
## 
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

##
sub show_html{
  print "Content-type: text/html\n\n";
  print qq(
<head>
<title>gbs_map</title>
  <style>
 #container{

  width: 95%;

  background-color: #F9F9F9;

  margin: auto;

  padding: 10px;

}
body{
  background-color: #f9f9f9;
}
  </style>
</head>
);
  print $q->start_html('gbs_map');
  #print $q->header();
  print qq(
<div id="container">
<FORM ACTION="/cgi-bin/gbs_map3.cgi" METHOD = POST NAME="MainForm" ENCTYPE= "multipart/form-data" target="_self">
<P>
Enter your tags below in comma-delimited format (including the header):<p>
<strong>Example:</strong><br>
<pre>
MarkerNUm,Reads,SNP_position,A_genotype_Lakin,B_genotype_Roefls_15,Reads_length<br>
1,TGCAGAAAAAACAGAAAGTCAAATCTGAGCACAAAAAATAGAGTCAAAATGAAGCTCCGTATCT,6,A,G,64<br>
2,TGCAGAAAAAACGCTTCTGACACAACGTGCCGAGAACGCTGAAGCCGCCCTTGAAGAGGTTACG,57,A,C,64<br>
3,TGCAGAAAAAATCAGTTTGCATTTACAACACATGAACACCAAGTCTGACATAGGTAGACCATCT,11,A,T,64<br>
4,TGCAGAAAAACGAAGATGGCGATGACATGGTCATGGCATACCCGAAGCTGGTCGAGCTATGTTC,53,T,C,64<br>
</pre>
<strong>Only the first two columns will be used.</strong><br>
<i>Note: Time out might happen if submit >40,000 tags.</i><br>
<BR>
<textarea name="SEQUENCE" rows=10 cols=100>
</textarea>
<BR>
Or load it from disk (should be the same format as mentioned in the example)<br>Click to select:
<INPUT TYPE="file" NAME="SEQFILE">
<P>
<INPUT TYPE="button" VALUE="Clear sequence" onClick="MainForm.SEQUENCE.value='';MainForm.SEQUENCE.focus();">
<INPUT TYPE="submit" VALUE="Search">
<HR>
</FORM>
);
  if($file){
    my $t = localtime(time);
    print "<ul>$t <br>Job submitted.</ul>";
   # print qq( <input type="text" name="val1" id="$file"
   # onkeyup="exported_func( ['$file'], ['resultdiv'] );">
   # <br>
   #  <div id="resultdiv"></div>
   # );
  }
  #print $q->end_html;
}

sub run_the_job{

  my $file = shift;
  my ($fasta, $expected_chr ) = make_fasta($file);
  
  my $blat_css_cmd = run_blat($fasta);
  my @blat_nrg_cmd = run_blat_nrg($fasta);
  my @blat_pop_cmd = run_blat_popseq($fasta);
  
  &parallel_blat($blat_css_cmd, @blat_nrg_cmd, @blat_pop_cmd); 

  my @blat_outputs = map{$1 if /(\S+)\s+1\>/}($blat_css_cmd,@blat_nrg_cmd, @blat_pop_cmd);
  
  
  my $parsed_out = parse_blat_output($file, $expected_chr, @blat_outputs);
  
  
  my $t = localtime(time);
  my %return;
  $return{"1.done_time"} = $t . " Job is finished.<br>";
  $return{"url"} = "http://download.txgen.tamu.edu/shichen/tmp/" . $parsed_out ;
  return %return
}

sub parallel_blat{
  my @cmds = @_;
  my $pm = Parallel::ForkManager->new(4);
  $pm->run_on_wait(
    sub {
      my $t = localtime(time);
    },
    3
  );
  LOOP:
  foreach my $cmd (@cmds) {
    # Forks and returns the pid for the child:
    my $pid = $pm->start and next LOOP;
    system($cmd);
    $pm->finish; # Terminates the child process
  }

  $pm->wait_all_children;
  return 0;
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

sub make_fasta {
  my $file = shift; 
  my $fasta = $file;
  my %chr;
  $fasta =~ s/csv$/fasta/;
  open (my $OUT, ">$fasta") or die $!;
  open (my $IN, $file) or die $!;
  my $l = 0;
  while(<$IN>){
    chomp; 
    $l++;
    next if /^\s+$/;
    s/\s//g;
    my @t=split /,/, $_;
    $chr{$t[0]} = $t[2] if defined $t[2] and $t[2]=~/\S/;
    print $OUT ">$t[0]\n$t[1]\n" if /\S/;
  }
  close $IN;
  close $OUT;
  return ($fasta, \%chr);
}

sub run_blat {
  my $f = shift;
  my $output = $f . "_blat.out";
  #my $blat = "/usr/local/bin/blat";
  #my $ref = "/home/DNA/ctgs/wheat_chr_contigs/formatted/all_chr_contigs_formatted_breakline_containGenes.fasta";
  #my $cmd = "$blat $ref $f -out=blast8 $output";
  my $cmd = "$gfClient -out=blast8  localhost 17779 / $f $output";
  #system("$cmd 1>/dev/null");
  #return $output;
  return "$cmd 1>/dev/null";
}

sub run_blat_nrg {
  my $f = shift;
  my @return;
  my @ports = map{17784+$_}1..7; ;
  foreach my $ind(1..7){
    my $output = $f . "_blat_nrg_chr${ind}.out";
    my $cmd =  "$gfClient -out=blast8  localhost $ports[$ind-1] / $f $output";
    push @return, "$cmd 1>/dev/null"
   } 
   return @return;
}

sub run_blat_popseq {
  my $f = shift;
  my @return;
  my @ports = (17782, 17783, 17784);
  foreach my $ind(0..2){
    my $output = $f . "_blat_pop_${ind}.out";
    my $cmd =  "$gfClient -out=blast8  localhost $ports[$ind] / $f $output";
    #system("$cmd 1>/dev/null");
    #push @return, $output;
    push @return, "$cmd 1>/dev/null"
  }
  return @return;
}

sub random_string {
  my $len = shift;
  my @arr = ("A".."Z", "a" .. "z", "_", "-", 0..9);
  my $str = "";
  map{$str  .=  $arr[int(rand(scalar @arr))]}1..$len;
  return $str . time();
}

sub parse_blat_output {
  my $file = shift;
  my $exp_chr = shift;
  my @tags = get_tags($file);
  my %h;
  my @files = @_;
  my $posref = &get_pos();
  my $popseq_ref = &get_popseq();  
  foreach my $ind ( 0.. $#files){
    my $f = $files[$ind];
    open(my $IN, $f) or die $!;
    my %g;

    while(<$IN>){
      chomp;
      my @t = split /\s+/, $_;
      # tag_1   5282575_2as     98.44   64      1       0       1       64      7298    7361    1.2e-27 121.0
      next if exists $g{$t[0]} or $t[3] < 50;
      $t[1] =~ s/_v2//;
      my $hit_chr = (split /_/, $t[1])[1]; $hit_chr = $1 if $t[1]=~/chr(\S{2})/;
      if(exists $exp_chr->{$t[0]}){ next unless $hit_chr =~ /$exp_chr->{$t[0]}/i;}
      $h{$t[0]} = [] unless exists $h{$t[0]};
      $h{$t[0]}[$ind] = join(",", @t[1,3,2,8]) unless defined $h{$t[0]}[$ind];
    }
    close $IN;
  }
  my %nrg_parts_to_chr = &parts_to_chr();
  my $out = $files[0] . ".parsed";
  open (my $OUT, " >$out") or die;
  print $OUT join(",", qw(Tag expected_chr CSS_Contig CSS_Chromosome CSS_cM Aligned_length Align_similarity W7984_Contig W7984_Chromosome W7984_cM Aligned_length Align_similarity PseudoM PseudoM_physicalPosition Aligned_length Align_similarity)), "\n";
  foreach my $tag (@tags){
    my @res = map{"NA"}1..14;
    if (exists $h{$tag}){
      # CSS: 0
      my @index = (0);
      my $blat_result = "";
      my @blat_results = sort{my @pa=split /,/, $a; my @pb=split /,/,$b; $pb[1] <=> $pa[1] or $pb[2] <=> $pa[2]}@{$h{$tag}}[@index];
      $blat_result = $blat_results[0] || "";
      if($blat_result=~/\S/){
        my ($ctg, $len, $sim) = split /,/, $blat_result;
        my $chr = $1 if $ctg =~ /_(\S+)/;
        my $cm = exists $popseq_ref->{$ctg}?$popseq_ref->{$ctg}:"NA";
        @res[0..4] = ($ctg, $chr, $cm, $len, $sim);
      }
      # nrgene: 1-7
      @index=(1..7);
      @blat_results = sort{my @pa=split /,/, $a; my @pb=split /,/,$b; $pb[1] <=> $pa[1] or $pb[2] <=> $pa[2]}@{$h{$tag}}[@index];
      $blat_result = $blat_results[0] || "";
      if($blat_result=~/\S/){
        my ($ctg, $len, $sim, $phy_pos) = split /,/, $blat_result;
        if(exists $nrg_parts_to_chr{$ctg}){my @bed = @{$nrg_parts_to_chr{$ctg}}; $ctg=$bed[3], $phy_pos += $bed[4] }
        @res[10..13] = ($ctg, $phy_pos, $len, $sim);
      }
      # W7984: 8..$
      @index=(8 .. $#files);
      @blat_results = sort{my @pa=split /,/, $a; my @pb=split /,/,$b; $pb[1] <=> $pa[1] or $pb[2] <=> $pa[2]}@{$h{$tag}}[@index];
      $blat_result = $blat_results[0] || "";
      if($blat_result=~/\S/){
        my ($ctg, $len, $sim) = split /,/, $blat_result;
        ($ctg, my $chr, my $cm) = split /_/, $ctg;
        @res[5..9] = ($ctg, $chr, $cm, $len, $sim);
      }
    }
    print $OUT join(",", $tag, (exists $exp_chr->{$tag}?$exp_chr->{$tag}:"NA"), @res), "\n";
  }

  close $OUT;
  my $link_file = "/home/shichen.wang/for_down/tmp/" .basename($out) . ".csv";
  system("mv $out  $link_file");
  return basename($link_file);
}

sub get_popseq{
  my $f = "/data4/.shichen/wheat_w7984/POPSEQ.hash";
  my $href = retrieve($f);
  return $href;  
}

sub get_pos {
  my $f = "/data4/.shichen/wheat_CSS/contigs_ordered_addGeneticDist_1Hfiltered";
  my $hash_file = $f . ".hash";
  unless(-e $hash_file){
    open(my $IN, $f) or die $!;
    my %hash;
    while(<$IN>){
      chomp; 
      my @t=split /\s+/,$_; 
      $hash{$t[0]} = [@t];
    }
    close $IN;
    store \%hash, $hash_file;
  }
  my $hashref = retrieve($hash_file);
  return $hashref;
}

sub get_tags {
  my $f = shift;
  open(my $IN, $f) or die;
  my @arr;
  my $l = 0;
  while(<$IN>){
    $l++;
    s/\s+//g;
    next if /^\s+$/;
    my @t=split /,/, $_;
    next unless @t;
    push @arr, $t[0] if $t[0]=~/\S/;
  }
  close $IN;
  return @arr;
}

sub parts_to_chr {
  my $f = "/data4/.shichen/wheat_pseudomolecular/v1.0/Wheat_IWGSC_WGA_v1.0_pseudomolecules/161010_Chinese_Spring_v1.0_pseudomolecules_parts_to_chr.bed";
  my %return;
  open(IN, $f) or die $!;
  while(<IN>){
    chomp;
    my @t = split /\s+/,$_; 
    $return{$t[0]} = [@t];
  }
  close IN;
  return %return;
}
