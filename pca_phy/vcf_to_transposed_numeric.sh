cat $1 | perl -ne 'if(/\#CHR/){chomp; @t=split /\s+/,$_; print join("\t", "SNP", @t[9..$#t]), "\n"}' >header
cat $1 |perl -ne 'next if /\#/; chomp; @t=split /\s+/,$_; next if $t[4]=~/\,/; @geno=();  map{if(/^([01])\/([01])/){push @geno, $1+$2}else{push @geno, "NA"} }@t[9..$#t]; print join("\t", $t[0]."-".$t[1], @geno), "\n"' |cat header - >${1}.numeric.txt
cat ${1}.numeric.txt | perl -ne 'chomp; $n++; @t=split /\s+/,$_; if($n==1){@arr=@t; next}else{map{push @{$h{$arr[$_]}}, $t[$_] }0..$#t;} END{map{print join(",", "\"".$_."\"", @{$h{$_}}), "\n"}@arr[0..$#arr]}' >${1}.numeric.txt.transposed
