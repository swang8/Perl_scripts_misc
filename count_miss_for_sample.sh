# count the missing genotypes for samples in vcf
VCF=$1

perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' $VCF >${VCF}_sample_missing_rate.txt


