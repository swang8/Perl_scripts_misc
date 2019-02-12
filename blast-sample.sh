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
    #if [[ $i != *.fastq.gz ]] ; then
    #    echo "Skipping $i"
    #fi

    # Get a sample from the FASTQ
    # Convert it to FASTA
    # Run through BLAST
    # Summarize BLAST output, showing the most likely organism
    #   One line per sequence
    # Count the number times each organism appears
    # Save to file
    
    # only blast a poriton 
    seqtk sample -s${SEED} "$i" $SAMPLE_SIZE  >${i}_rand${SAMPLE_SIZE}.fq 
    seqtk sample $i $SAMPLE_SIZE |  seqtk seq -A  | blastn -db nt -num_threads 10 -num_alignments 1 -outfmt '6 qseqid stitle qcovs'  > ${i}_rand${SAMPLE_SIZE}.blast.out
    
    # all reads
    #seqtk seq -A $i | blastn -db nt -num_threads 10 -num_alignments 1 -outfmt '6 qseqid stitle qcovs'  > ${i}_blast.out
    
done
