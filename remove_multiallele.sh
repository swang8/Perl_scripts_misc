# remove variations with multi-allels for ALT in VCF
perl -ne 'if(/\#/){print $_; next}@t=split /\s+/,$_; print $_ unless $t[4]=~/\,/' $1  >${1}_rmMulti.vcf

