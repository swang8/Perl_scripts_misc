VCF=$1

# remove multiple allele variatons;
perl -ne 'if(/\#/){print $_; next} @t=split /\s+/,$_; print $_  unless $t[4]=~/\,/' $VCF >${VCF}_rmMulti.vcf

# Phasing with eagle2
echo "phasing start"
date
eagle --vcf ${VCF}_rmMulti.vcf --geneticMapFile=~/genetic_Map_1cmMb.txt --outPrefix=${VCF}_phased.vcf
date
echo "phasing end"

# impute with minimac3

