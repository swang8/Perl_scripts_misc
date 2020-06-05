vcf=$1
hmp=${vcf}.hmp.txt

perl  ~/pl_scripts/vcf_to_hmp_v2.pl $vcf >$hmp
