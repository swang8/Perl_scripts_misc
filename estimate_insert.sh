#!/bin/bash

# r1.fq.gz r2.fq.gz

R1=$1
R2=$2

acc=`perl -MFile::Basename -e '$f=shift; $ba=basename($f); $acc=$1 if $ba=~/^(\S+)\SR1/; print $acc,"\n"' $R1 `

SAMPLE=5000

seqtk seq -A $R1 | perl -ne 'BEGIN{$sample = 5000}$n++; exit if $n > $sample * 2; print $_' >${acc}_${SAMPLE}_reads_R1.fa
seqtk seq -A $R2 | perl -ne 'BEGIN{$sample = 5000}$n++; exit if $n > $sample * 2; print $_' >${acc}_${SAMPLE}_reads_R2.fa

module load blast
if [ ! -e ${acc}_${SAMPLE}_reads_R1.blastnt.out.parsed ]; then
  blastn -db nt -query ${acc}_${SAMPLE}_reads_R1.fa -num_threads 10 -num_alignments 1 -out ${acc}_${SAMPLE}_reads_R1.blastnt.out
  blastn -db nt -query ${acc}_${SAMPLE}_reads_R2.fa -num_threads 10 -num_alignments 1 -out ${acc}_${SAMPLE}_reads_R2.blastnt.out
fi

perl ~/parse_blast.pl ${acc}_${SAMPLE}_reads_R1.blastnt.out >${acc}_${SAMPLE}_reads_R1.blastnt.out.parsed
perl ~/parse_blast.pl ${acc}_${SAMPLE}_reads_R2.blastnt.out >${acc}_${SAMPLE}_reads_R2.blastnt.out.parsed

perl ~/pl_scripts/estimate_insert_length.pl ${acc}_${SAMPLE}_reads_R1.blastnt.out.parsed ${acc}_${SAMPLE}_reads_R2.blastnt.out.parsed >${acc}_insert_len.tsv

Rscript ~/hist_plot.R ${acc}_insert_len.tsv
