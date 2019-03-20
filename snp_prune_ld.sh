bed=$1

# first get the list
plink --noweb --bfile ${bed/.bed/} --out ${bed/.bed/} --indep 50 5 2

# pruned
plink --bfile ${bed/.bed/} --extract ${bed/.bed/}.prune.in --make-bed --out ${bed/.bed/}_pruned
