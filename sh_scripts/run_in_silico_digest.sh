# files=(chara_genome.fasta.gz chloroplast.sequence.fasta.txt.gz bacterial_top10.gz)
files=( chloroplast.sequence.fasta.txt.gz )
for f in ${files[@]}; do
  echo $f
  zcat $f | combine >${f}.seq
  dbcut -o ${f}.db ${f}.seq  AscI FseI NotI SbfI AsiSI PacI MboI MluCI MseI MspI NlaIII EcoRI HindIII PstI SpeI SphI
  
  # pick enzymes you want to make plots with
  enzymes=(AscI FseI NotI SbfI AsiSI PacI MboI MluCI MseI MspI NlaIII EcoRI HindIII PstI SpeI SphI)
  enz_list_len=${#enzymes[@]}
  for (( i=0; i<${enz_list_len}; i++ ));
  do
     dbchart -i ${f}.db  ${enzymes[$i]}  -o ${f}_${enzymes[$i]}.pdf
     for (( j=i+1; j<${enz_list_len}; j++ ));
     do
	echo ${enzymes[$i]} ${enzymes[$j]}
  	dbchart -i ${f}.db  ${enzymes[$j]} ${enzymes[$i]} -o ${f}_${enzymes[$j]}_${enzymes[$i]}.pdf
     done
  done

done

## convert pdf to jpeg
perl -e '@fs=<*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/; next if -e $jpeg; $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'

## generate html page
#sh generate_page.sh > in_silico_reports.html
