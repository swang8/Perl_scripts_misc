perl -ne 'BEGIN{$f=$ARGV[0]}  $n++; $cla++ if /^C/; END{print $f, "\t", $cla/$n, "\n"}' $1
