perl -ne '$n++; next if $n==1; next unless /\S/; @t=split /,/, $_; print join("\t", @t[3,6]), "\n" ' $1 |sort -k1,1 |more
