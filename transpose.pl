my @arr  = ();
my $max_col = 0;
while(<>){
    print STDERR $_ ; 
    chomp;
    my @t = split /\s+/, $_;
    push @arr, [@t];
    $max_col = $#t if $#t > $max_col;
}

foreach my $i (0..$max_col){
my @tmp = ();
map{push @tmp, $arr[$_][$i]}0..$#arr;
print join("\t", @tmp), "\n"
}
