#!perl -w
use strict;

die "perl $0 <dir>\n" unless @ARGV;

my $p = &dir_walk($ARGV[0]);
while (my $f = $p->()){
    print ($f . "\n");
}

sub dir_walk {
    my @fs = ();
    my $d = shift;
    push @fs, "$d";
    my $func = sub {
      my $p = shift @fs;
      return unless $p;
      if (-d $p){
          my @arr;
          opendir(my $dh, $p) || die "Can't open $p: $!";
          while (readdir $dh) {
            push @arr, "$p/$_" unless $_ eq "." or $_ eq "..";
          }
          closedir $dh;
          push @fs, @arr;
      }
      return $p
    };
    return $func;
}
