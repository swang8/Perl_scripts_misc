#!/bin/bash
args=$@

array=($args)
if [ ${#array[@]} -eq 0 ]; then
    echo ""
    echo "Usage: remove_dup  <directory or filenames>"
    echo "       The files need to have \".fastq.gz\" as postfix."
    echo ""
    exit 1
fi

echo "Remove duplicate reads based on tile coordinates"
echo ""

for INPUT in ${args[@]}; do

    if [ -d $INPUT ]; then
       files=$(find $INPUT -name "*fastq.gz")
       for file in ${files[@]}; do
          echo $file
          tmp=/tmp/$(basename $file).tmp
          zcat $file | perl -ne '$n++; if($n==1){$m++; @t=split /[:\s]/, $_; $id=join(" ", @t[3..6]); $f=0;  if(exists $h{$id}){$f=1; $dup++}; $h{$id}=1} print $_ unless $f; $n=0 if $n==4; END{print STDERR " duplicate rate: ", sprintf("%.2f", $dup/$m*100), "%\n\n"}' | gzip - >$tmp
          mv $tmp $file
       done 
    else
       file=$INPUT
       echo $file
       tmp=/tmp/$(basename $file).tmp
       zcat $file | perl -ne '$n++; if($n==1){$m++;@t=split /[:\s]/, $_; $id=join(" ", @t[3..6]); $f=0;  if(exists $h{$id}){$f=1; $dup++}; $h{$id}=1} print $_ unless $f; $n=0 if $n==4; END{print STDERR " duplicate rate: ", sprintf("%.2f", $dup/$m*100), "%\n\n"}' | gzip - >$tmp
       mv $tmp $file   
    fi
done
