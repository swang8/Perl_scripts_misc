#!/bin/bash
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

set -eu
set -o pipefail

module load blast
module load seqtk

#set -x

SAMPLE_SIZE=1000
SEED=42

LIBDIR=`dirname $0`

for i in $* ; do
    # If it's not a read, skip to next file
    if [[ $i != *R1_001.fastq.gz ]] ; then
        echo "Skipping $i"
    fi

    # Get a sample from the FASTQ
    # Convert it to FASTA
    # Run through BLAST
    # Summarize BLAST output, showing the most likely organism
    #   One line per sequence
    # Count the number times each organism appears
    # Save to file
    
    # only blast a poriton 
    # seqtk sample -s${SEED} "$i" $SAMPLE_SIZE  >${i}_rand${SAMPLE_SIZE}.fq 
    perl -e '$s=shift; $f=shift; open(IN, "zcat $f |"); $line=0;  while(<IN>){$line++; print $_; exit if $line == $s*4}' ${SAMPLE_SIZE} ${i} >${i}_rand${SAMPLE_SIZE}.fq
    seqtk seq -A  ${i}_rand${SAMPLE_SIZE}.fq | blastn -db nt -num_threads 10 -num_alignments 1 -outfmt '6 qseqid stitle qcovs'  > ${i}_rand${SAMPLE_SIZE}.blast.out
    
    # all reads
    #seqtk seq -A $i | blastn -db nt -num_threads 10 -num_alignments 1 -outfmt '6 qseqid stitle qcovs'  > ${i}_blast.out
    perl -ne 'BEGIN{$f=$ARGV[0]}chomp;  @t=split /\s+/,$_; next if exists $h{$t[0]}; $spe=$1 if /^\S+\s+(\S+\s+\S+)/; $spe=$1 if /PREDICTED:\s+(\S+\s+\S+)/; $h{$t[0]}=1; $g{$spe}+= 1;END{ $tot=0; map{$tot += $_}values %g; @arr=sort{$g{$b} <=> $g{$a}}keys %g; @ps=map{$_. "_" . sprintf("%.2f", $g{$_}/$tot)}@arr[0..2];    print $f, "\t", join(";", @ps), "\n"; map{print STDERR $_, "\t", $g{$_}, "\n"}@arr[0..2]}' ${i}_rand${SAMPLE_SIZE}.blast.out >${i}_rand${SAMPLE_SIZE}.blast.out.top3
    
done
