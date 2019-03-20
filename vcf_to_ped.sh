vcf=$1

# to hmp
hmp=${vcf/.vcf/.hmp.txt}
perl ~/pl_scripts/vcf_to_hmp_v2.pl $vcf >$hmp

# to ped
perl ~/pl_scripts/hmp_to_ped.pl $hmp

# to bed
plink --noweb --file $hmp --make-bed --recode --out ${vcf/.vcf/} --missing-genotype N --missing-phenotype 0
