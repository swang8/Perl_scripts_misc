## input vcf
imputed_vcf=$1

## filter with GP
perl -ne 'BEGIN{$gp_cutoff = 0.8} if(/^\#/){print $_; next} chomp; @t=split /\s+/,$_;  foreach $i (9 .. $#t){@arr=split /:/, $t[$i]; @gp=split /,/, $arr[-1]; $ind=($arr[0]=~/0\/0/?0:($arr[0]=~/0\/1/?1:2)); $t[$i] = "./." unless $gp[$ind] >= $gp_cutoff;} print join("\t", @t), "\n"' $1 >${1}_GPfiltered

