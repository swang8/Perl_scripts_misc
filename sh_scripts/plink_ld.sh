data=$1

plink --noweb --file $data --missing-genotype N --ld-window-kb 1000  --ld-window 99999 --ld-window-r2 0 --out ${data}.plink
