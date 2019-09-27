csv=$1
out=${csv/csv/sorted.csv}
perl -ne '$n++; if($n==1){print $_ ;next} chomp; @t=split /,/, $_; push @arr, [@t]; END{@arr=sort{$a->[3] <=> $b->[3]}@arr; map{print join(",", @{$_}), "\n"}@arr}'  $csv >$out
