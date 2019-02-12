# suppose a list of vcf files were provided
vcfs=$@

# step 1: filtering with max missing 0.5 and MF 0.05
MAX_MISSING=0.5
MIN_MAF=0.05

VCF=$vcfs
OUTPUT=agseq_filtered_MaxMissing${MAX_MISSING}_MinMAF${MIN_MAF}.vcf

perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){if(/\#/){if(/\#CHROM/){print $_ unless $header; $header=1}; next}; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISSING $MIN_MAF $VCF >$OUTPUT

# step 2: calculate missing and maf; then make plots
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"' $OUTPUT >${OUTPUT}.missing.maf.txt

cut -f 4  ${OUTPUT}.missing.maf.txt >Missing_rate.txt

perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' $OUTPUT >${OUTPUT}_sample_missing_rate.txt

more {OUTPUT}_sample_missing_rate.txt | cut -f 4  >sample_missing.txt

Rscript ~/pl_scripts/histogram.R  -i Missing_rate.txt -e 1 -t "SNP missing rate"

Rscript ~/pl_scripts/histogram.R  -i sample_missing.txt -e 0 -t "Sample missing rate" -x "Missing rate"

# step 3: imputation
beagle="/home/shichen.wang/Tools/beagle.21Jan17.6cc.jar"
IMPINPUT=$OUTPUT
perl ~/pl_scripts/impute_miss.pl  $beagle  $IMPINPUT

# step 4: evaluate imputation accuracy with random masking of 5% of genotyped data as missing
sh ~/pl_scripts/imputation/run.sh $IMPINPUT 0.05 

perl -e '@fs=<imp_eval/*.tsv>; foreach $f(@fs){$cmd="sh /home/shichen.wang/pl_scripts/imputation/summarize.sh $f >${f}_AF.txt; sh /home/shichen.wang/pl_scripts/imputation/summarize_v2.sh $f"; print $cmd, "\n"; system($cmd)}'

# plot imputation accuracy per allele frequency range
ls imp_eval/*AF.txt | parallel -j 1 Rscript /home/shichen.wang/pl_scripts/plot_imputation_accuracy_AF.R {}

# plot general imputation accuracy based on GP

