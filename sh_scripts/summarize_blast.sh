## if the blast output format is "  -outfmt '6 qseqid stitle ...' "
perl -ne 'BEGIN{$file=$ARGV[0]; print $file, "\n"} @t=split /\t/, $_; next if exists $h{$t[0]}; $h{$t[0]}=1; $name=$1 if $t[1]=~/^(\S+\s+\S+)/; $g{$name}++; END{$tot=scalar keys %h;  map{print $_, "\t", $g{$_}, "\t",  $g{$_}/$tot, "\n" }sort{$g{$b}<=>$g{$a}}keys %g;}' $1 | head -n 11
