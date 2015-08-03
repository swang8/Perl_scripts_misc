#!/usr/bin/perl -w
use strict;

my ($dir, $days) = @ARGV;

die "perl $0 <dir> <days>\n" unless @ARGV == 2;

$days = 1 if $days =~ /\D/;

my $d = dir_walk($dir);

my $current = time();

while(my $f = &$d){
  next if -d $f;
  my $t = (stat($f))[9];
  if(abs($t - $current) > ($days * 24 * 60 * 60) ){
    system("rm $f");
  }  
}


sub dir_walk
{
  my $dir = shift;
  my @queue;
  if(not -d $dir){push @queue, $dir}
  else{ my @df=<$dir/*>;  push @queue, @df}
  my $iterator = sub{
   my $f = pop @queue;
   return unless $f;
   if (-d $f){my @fs=<$f/*>; push @queue, @fs}
   return $f;
  };
  return $iterator;
}
