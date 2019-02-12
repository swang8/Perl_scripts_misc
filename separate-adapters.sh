#!/bin/bash
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

#module load python
#module load cutadapt

#set -x
set -eu

# Default to fastest compression
export GZIP="-1"

CUTADAPT="cutadapt  -O4 --quiet"
FWD="-a AGATCGGAAGAGCACACGTC -a GACGTGTGCTCTTCCGATCT -a AGATCGGAAGAGCGGTTCAG -a CTGAACCGCTCTTCCGATCT -a GATCGGAAGAGCGGTTCAGCAGGAATGCCGAG"
REV="-a AGATCGGAAGAGCGTCGTGT -a ACACGACGCTCTTCCGATCT -a ACACTCTTTCCCTACACGACGCTCTTCCGATCT"

for R1 in $* ; do
    # If it's not R1, skip to next file
    if [[ $R1 != *_R1_001.fastq.gz ]] ; then
        echo "Skipping $R1"
        continue
    fi

    # Based on R1, find the base filename
    R_base=`basename $R1 _R1_001.fastq.gz`
    R_dir=`dirname $R1`

    R1_in=${R_dir}/${R_base}_R1_001.fastq.gz
    R2_in=${R_dir}/${R_base}_R2_001.fastq.gz

    R1_adp=${R_dir}/${R_base}_R1_001.ADAPTER_FOUND.fastq.gz
    R2_adp=${R_dir}/${R_base}_R2_001.ADAPTER_FOUND.fastq.gz

    R1_out=${R_dir}/${R_base}_R1_001.NO_ADAPTER.fastq.gz
    R2_out=${R_dir}/${R_base}_R2_001.NO_ADAPTER.fastq.gz

    if [[ -a $R2_in ]] ; then
        # Paired-End
        #
        # There are four possible combinations for adapter presence:
        #
        #           +----+----+
        #           | R1 | R2 |   Output
        # +---------+----+----+ -----------------
        # | Adapter | N  | N  | >  no adapter
        # | found   | N  | Y  | \
        # |         | Y  | N  |  ) adapter found
        # |         | Y  | Y  | /
        # +---------+----+----+
        #
        # cutadapt tests one read at a time, but can apply the results to
        # both reads (--paired-output mode)
        # 
        # We can separate the combinations with 6 runs of cutadapt
        #
        # This produces 6 matched pairs of FASTQ files
        #
        # R1/2                            R1/2
        # -------------------------------------
        #  u/u => discard-trimmed(R1)   => n/u
        #  n/u => discard-trimmed(R2)   => n/n
        #  n/u => discard-untrimmed(R2) => n/y
        #  u/u => discard-untrimmed(R1) => y/u
        #  y/u => discard-trimmed(R2)   => y/n
        #  y/u => discard-untrimmed(R2) => y/y
        #
        #     u = undetermined
        #     y = adapter
        #     n = no adapter
        #
        #          uu
        #        /    \
        #       nu     yu
        #      / \     / \
        #     /   \   /   \
        #    nn   ny yn   yy

        echo PE $R1_in $R2_in

        R1_uu=$R1_in
        R1_nu=${R_dir}/${R_base}_R1_001_nu.fastq.gz
        R1_nn=${R_dir}/${R_base}_R1_001_nn.fastq.gz
        R1_ny=${R_dir}/${R_base}_R1_001_ny.fastq.gz
        R1_yu=${R_dir}/${R_base}_R1_001_yu.fastq.gz
        R1_yn=${R_dir}/${R_base}_R1_001_yn.fastq.gz
        R1_yy=${R_dir}/${R_base}_R1_001_yy.fastq.gz

        R2_uu=$R2_in
        R2_nu=${R_dir}/${R_base}_R2_001_nu.fastq.gz
        R2_nn=${R_dir}/${R_base}_R2_001_nn.fastq.gz
        R2_ny=${R_dir}/${R_base}_R2_001_ny.fastq.gz
        R2_yu=${R_dir}/${R_base}_R2_001_yu.fastq.gz
        R2_yn=${R_dir}/${R_base}_R2_001_yn.fastq.gz
        R2_yy=${R_dir}/${R_base}_R2_001_yy.fastq.gz

        (
            $CUTADAPT $FWD --discard-trimmed   --paired-output "$R2_nu" --output "$R1_nu" "$R1_uu" "$R2_uu"

            $CUTADAPT $REV --discard-trimmed   --paired-output "$R1_nn" --output "$R2_nn" "$R2_nu" "$R1_nu" &
            $CUTADAPT $REV --discard-untrimmed --paired-output "$R1_ny" --output "$R2_ny" "$R2_nu" "$R1_nu" &
            wait

            rm $R1_nu $R2_nu
        ) &
        (
            $CUTADAPT $FWD --discard-untrimmed --paired-output "$R2_yu" --output "$R1_yu" "$R1_uu" "$R2_uu"

            $CUTADAPT $REV --discard-trimmed   --paired-output "$R1_yn" --output "$R2_yn" "$R2_yu" "$R1_yu" &
            $CUTADAPT $REV --discard-untrimmed --paired-output "$R1_yy" --output "$R2_yy" "$R2_yu" "$R1_yu" &
            wait

            rm "$R1_yu" "$R2_yu"
        ) &
        wait

        mv "$R1_nn" "$R1_out"
        mv "$R2_nn" "$R2_out"

        cat "$R1_yn" "$R1_ny" "$R1_yy" > "$R1_adp"
        rm  "$R1_yn" "$R1_ny" "$R1_yy"
        cat "$R2_yn" "$R2_ny" "$R2_yy" > "$R2_adp"
        rm  "$R2_yn" "$R2_ny" "$R2_yy"

        mv "$R1_out" "$R1_in"
        mv "$R2_out" "$R2_in"
    else
        # Single-End
        echo SE $R1

        $CUTADAPT $FWD --untrimmed-output "$R1_out" --output "$R1_adp" "$R1_in"

        mv "$R1_out" "$R1_in"
    fi
done
