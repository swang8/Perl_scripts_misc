module load parallel

# suppose a list of vcf files were provided
vcfs=$@

# step 1: filtering with max missing 0.5 and MF 0.05
MAX_MISSING=0.5
MIN_MAF=0.05

VCF=$vcfs
OUTPUT=agseq_filtered_MaxMissing${MAX_MISSING}_MinMAF${MIN_MAF}.vcf

# vcfcombine chr*_MaxMissing0.5_MinMAF0.05_SNPs.vcf >$OUTPUT

perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){if(/\#/){if(/\#CHROM/){print $_ unless $header; $header=1}; next}; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISSING $MIN_MAF $VCF >$OUTPUT

perl -ne 'next if /\#/; $chr=$1 if /^(\S+)/; $h{$chr}++; END{map{print $_, "\t", $h{$_}, "\n"; $tot += $h{$_}}sort{$a cmp $b}keys %h; print "Total\t$tot\n"}' $OUTPUT >${OUTPUT}.var.count.txt


# step 2: calculate missing and maf; then make plots
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; $r++; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"; @geno=@t[9..$#t]; map{$sam[$_]++ if $geno[$_]=~/\.\/\./}0..$#geno; END{map{print STDERR join("\t", $_, $r, $sam[$_], $sam[$_]/$r), "\n"} 0..$#sam;}' $OUTPUT >${OUTPUT}.missing.maf.txt 2>${OUTPUT}_sample_missing_rate.txt

cut -f 4  ${OUTPUT}.missing.maf.txt >Missing_rate.txt
avg_miss=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' Missing_rate.txt)

perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' $OUTPUT >${OUTPUT}_sample_missing_rate.txt

more ${OUTPUT}_sample_missing_rate.txt | cut -f 4  >sample_missing.txt
avg_miss_sample=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' sample_missing.txt)

Rscript ~/pl_scripts/histogram.R  -i Missing_rate.txt -e 1 -t "SNP missing rate" -s "No imputation, average missing rate: $avg_miss" -x "Missing rate"

Rscript ~/pl_scripts/histogram.R  -i sample_missing.txt -e 0 -t "Sample missing rate" -s "No imputation, average missing rate: $avg_miss_sample" -x "Missing rate"


# step 3: imputation
beagle="/home/shichen.wang/Tools/beagle.21Jan17.6cc.jar"
IMPINPUT=$OUTPUT
perl ~/pl_scripts/impute_miss.pl  $IMPINPUT $beagle

mkdir imputed
mv *imputed.vcf.gz imputed/

## filter imputed vcf using GP=0.9
ls imputed/*gz |  parallel -j 3 sh /home/shichen.wang/pl_scripts/imputation/proc_imputed-vcf.sh {} 0.9
ls imputed/*gz |  parallel -j 3 sh /home/shichen.wang/pl_scripts/imputation/proc_imputed-vcf.sh {} 0.8
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"' imputed/*GPfiltered_0.9.vcf  >imputed_GP0.9.missing.maf.txt
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"' imputed/*GPfiltered_0.8.vcf  >imputed_GP0.8.missing.maf.txt

cut -f 4  imputed_GP0.9.missing.maf.txt >GP_0.9.Missing_rate.txt
cut -f 4  imputed_GP0.8.missing.maf.txt >GP_0.8.Missing_rate.txt
avg_miss_GP9=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' GP_0.9.Missing_rate.txt)
avg_miss_GP8=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' GP_0.8.Missing_rate.txt)


perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' imputed/*GPfiltered_0.9.vcf  >imputed_GP0.9_sample_missing_rate.txt
perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' imputed/*GPfiltered_0.8.vcf  >imputed_GP0.8_sample_missing_rate.txt

more imputed_GP0.9_sample_missing_rate.txt | cut -f 4  >GP_0.9_sample_missing.txt
more imputed_GP0.8_sample_missing_rate.txt | cut -f 4  >GP_0.8_sample_missing.txt
avg_miss_GP9_sam=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' GP_0.9_sample_missing.txt)
avg_miss_GP8_sam=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' GP_0.8_sample_missing.txt)

Rscript ~/pl_scripts/histogram.R  -i GP_0.9.Missing_rate.txt -e 1 -t "SNP missing rate" -s "Imputed and filtered with GP>=0.9\nAverage missing rate: $avg_miss_GP9" -x "Missing rate"
Rscript ~/pl_scripts/histogram.R  -i GP_0.8.Missing_rate.txt -e 1 -t "SNP missing rate" -s "Imputed and filtered with GP>=0.8\nAverage missing rate: $avg_miss_GP8" -x "Missing rate"

Rscript ~/pl_scripts/histogram.R  -i GP_0.9_sample_missing.txt -e 0 -t "Sample missing rate" -s  "Imputed and filtered with GP>=0.9\nAverage missing rate: $avg_miss_GP9_sam" -x "Missing rate"
Rscript ~/pl_scripts/histogram.R  -i GP_0.8_sample_missing.txt -e 0 -t "Sample missing rate" -s  "Imputed and filtered with GP>=0.8\nAverage missing rate: $avg_miss_GP8_sam" -x "Missing rate"


# step 4: evaluate imputation accuracy with random masking of 5% of genotyped data as missing
sh ~/pl_scripts/imputation/run.sh $IMPINPUT 0.03

perl -e '@fs=<imp_eval/*.tsv>; foreach $f(@fs){$cmd="sh /home/shichen.wang/pl_scripts/imputation/summarize.sh $f >${f}_AF.txt; sh /home/shichen.wang/pl_scripts/imputation/summarize_v2.sh $f"; print $cmd, "\n"; system($cmd)}'

# plot imputation accuracy per allele frequency range
ls imp_eval/*AF.txt | parallel -j 1 Rscript /home/shichen.wang/pl_scripts/plot_imputation_accuracy_AF.R {}

# plot general imputation accuracy based on GP
ls imp_eval/*sum.table.csv | parallel -j 1 Rscript /home/shichen.wang/pl_scripts/plot_imputation_accuracy_sum_table.R

# convert pdf to jpeg

perl -e '@fs=<*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'
perl -e '@fs=<imp_eval/*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'
