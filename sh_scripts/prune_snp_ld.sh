data=$1

out=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)

plink --noweb --file $data --missing-genotype N --allow-no-sex --indep-pairwise 50 5 0.5 --out $out

plink --noweb --file $data --missing-genotype N --allow-no-sex --extract ${out}.prune.in --make-bed --out ${data}_pruned
