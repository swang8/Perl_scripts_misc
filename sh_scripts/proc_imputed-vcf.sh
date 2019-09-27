## input vcf
imputed_vcf=$1
CUT=$2

## filter with GP
perl -e '$f= shift; $gp_cut=shift; if($f=~/gz$/){open(IN, "zcat $f |") or die $!}else{open(IN, $f) or die $!} while(<IN>){if(/^\#/){print $_; next} chomp; @t=split /\s+/,$_;  foreach $i (9 .. $#t){@arr=split /:/, $t[$i]; @gp=split /,/, $arr[-1]; $ind=($arr[0]=~/0\/0/?0:($arr[0]=~/0\/1/?1:2)); $t[$i] = "./." unless $gp[$ind] >= $gp_cutoff;} print join("\t", @t), "\n" } close IN;' $1 $2  >${1}_GPfiltered_${2}.vcf

