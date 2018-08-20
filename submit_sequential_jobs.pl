#!/usr/bin/perl -w
my @arr; 
while(<>){
  next if /^\#/ or /^\s+$/;
  chomp;
  push @arr, $_;
}

my $job="";
foreach my $ind (0..$#arr){
  if ($ind == 0){
    my $cmd = "bsub < $arr[$ind]";
    print $cmd, "\n";
    my $r = `$cmd`;
    $job = $1 if $r =~ /<(\d+)>/;
  }
  else{
    unless ($job){ print "Failed running $arr[$ind-1] !!";  exit }
    my $cmd = "bsub -w \"done($job)\" < $arr[$ind]";
    print $cmd, "\n";
    my $r = `$cmd`;
    $job = $1 if $r =~ /<(\d+)>/;
  }
}
