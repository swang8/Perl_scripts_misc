module load parallel
module load Java/1.8.0_92
module load R_tamu/3.5.2-foss-2018b-recommended-mt

echo "Make sure you have the R package "optparse" installed already. "
echo "If not, go to the Ada login terminal (not the terminal that is running the job), then use the following commands:"
echo "wget -O optparse.tar.gz  https://github.com/trevorld/r-optparse/archive/v1.6.2.tar.gz"
echo "R CMD INSTALL -l ~/R/x86_64-pc-linux-gnu-library  optparse.tar.gz"
echo "rm optparse.tar.gz"

echo ""

SCRIPT=`echo $0`
SCRIPT_PATH=$(perl -MCwd -MFile::Basename -e '$s=shift; $abs= Cwd::abs_path($s); print dirname($abs), "\n"' $SCRIPT)

echo "This is the path for all the scripts: " $SCRIPT_PATH
echo "Please copy the Beagle jar file you wan to use to that directory."
echo "If multiple version of Beagle presented, this script will pick the first one in alphabeta order."

echo "---------------------------------------"

echo "Is there a VCF for the reference panel provided?"
echo "If provided, the first VCF will be considered as the reference panel"
echo "Please enter Y for yes or N for no:"

read ref_available

if [ $ref_available == "Y" ] || [ $ref_available == "y" ]; then
   echo "Great, a reference panel is provided!"
else
   echo "No reference panel!"
fi
echo ""
date

# suppose a list of vcf files were provided
vcfs=($@)

if [ $ref_available == "Y" ] || [ $ref_available == "y" ]; then
  REFPANEL=${vcfs[0]} # the first vcf should the the ref panel
  echo ""
  echo "REFPANEL: $REFPANEL"
  echo ""
  vcfs[0]=""
  VCF=${vcfs[@]:1}
else
  VCF=${vcfs[@]:0}
fi

echo "step 1: filtering with max missing 0.5 and MF 0.05"
MAX_MISSING=0.5
MIN_MAF=0.05

OUTPUT=agseq_filtered_MaxMissing${MAX_MISSING}_MinMAF${MIN_MAF}.vcf

# vcfcombine chr*_MaxMissing0.5_MinMAF0.05_SNPs.vcf >$OUTPUT

perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){if(/\#/){if(/\#CHROM/){print $_ unless $header; $header=1}; next}; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISSING $MIN_MAF $VCF >$OUTPUT

perl -ne 'next if /\#/; $chr=$1 if /^(\S+)/; $h{$chr}++; END{map{print $_, "\t", $h{$_}, "\n"; $tot += $h{$_}}sort{$a cmp $b}keys %h; print "Total\t$tot\n"}' $OUTPUT >${OUTPUT}.var.count.txt

date
echo "step 2: calculate missing and maf; then make plots"
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; $r++; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"; @geno=@t[9..$#t]; map{$sam[$_]++ if $geno[$_]=~/\.\/\./}0..$#geno; END{map{print STDERR join("\t", $_, $r, $sam[$_], $sam[$_]/$r), "\n"} 0..$#sam;}' $OUTPUT >${OUTPUT}.missing.maf.txt 2>${OUTPUT}_sample_missing_rate.txt

cut -f 4  ${OUTPUT}.missing.maf.txt >Missing_rate.txt
avg_miss=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' Missing_rate.txt)

perl -ne '@t=split /\s+/,$_; if(/\#CHR/){@arr=@t} next if /\#/; map{$h{$arr[$_]}++; $m{$arr[$_]}++ if $t[$_]=~/\.\/\./ }9..$#t; END{map{print join("\t", $_,  $h{$_}, $m{$_}, $m{$_}/$h{$_}), "\n"}keys %h;}' $OUTPUT >${OUTPUT}_sample_missing_rate.txt

cat ${OUTPUT}_sample_missing_rate.txt | cut -f 4  >sample_missing.txt
avg_miss_sample=$(perl -ne 'next if /rate/; $n++; chomp; $m+= $_; END{print sprintf("%.2f", $m/$n), "\n"}' sample_missing.txt)

Rscript $SCRIPT_PATH/histogram.R  -i Missing_rate.txt -e 1 -t "SNP_missing_rate" -s "No_imputation.Average_missing_rate:$avg_miss" -x "Missing_rate"

Rscript $SCRIPT_PATH/histogram.R  -i sample_missing.txt -e 0 -t "Sample_missing_rate" -s "No_imputation.Average_missing_rate:$avg_miss_sample" -x "Missing_rate"

date
echo "step 3: imputation"
jar=(`ls $SCRIPT_PATH/beagle*.jar`)
beagle=${jar[0]}

IMPINPUT=$OUTPUT

if [ $ref_available == "Y" ] || [ $ref_available == "y" ]; then
  echo "perl $SCRIPT_PATH/impute_miss_with_ref_panel.pl  $IMPINPUT $REFPANEL $beagle"
  perl $SCRIPT_PATH/impute_miss_with_ref_panel.pl  $IMPINPUT $REFPANEL $beagle
  OVERLAPPEDVCF=${IMPINPUT/.vcf/_overlapped.vcf}
else
  echo "perl ~/pl_scripts/impute_miss.pl  $IMPINPUT $beagle"
  #perl $SCRIPT_PATH/impute_miss.pl  $IMPINPUT $beagle
fi

mkdir imputed
mv *imputed.vcf.gz imputed/

zcat imputed/*.gz | perl -ne 'next if /\#/; chomp;   @t=split /\s+/,$_;   map{@arr=split /[:,]/, $_; ($ref, $alt)=($1, $2) if /^(\d)\/(\d)/; foreach $ind(1..10){if($arr[2+$ref+$alt]>=$ind/10){$m{$ind}++}  }   }@t[9..$#t]; $n++; $p = $n * ($#t-8);  END{map{print $_/10, "\t", $m{$_}/$p, "\n"}1..10 } ' >GP_cutoff_remain.txt

date
## filter imputed vcf using GP=0.9
echo "filter imputed vcf using GP=0.9"
ls imputed/*gz |  parallel -j 3 sh $SCRIPT_PATH/imputation/proc_imputed-vcf.sh {} 0.9
ls imputed/*gz |  parallel -j 3 sh $SCRIPT_PATH/imputation/proc_imputed-vcf.sh {} 0.8
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

Rscript $SCRIPT_PATH/histogram.R  -i GP_0.9.Missing_rate.txt -e 1 -t "SNP_missing_rate" -s "Imputed_and_filtered_with_GP>=0.9|Average_missing_rate:$avg_miss_GP9" -x "Missing_rate"
Rscript $SCRIPT_PATH/histogram.R  -i GP_0.8.Missing_rate.txt -e 1 -t "SNP_missing_rate" -s "Imputed_and_filtered_with_GP>=0.8|Average_missing_rate:$avg_miss_GP8" -x "Missing_rate"

Rscript $SCRIPT_PATH/histogram.R  -i GP_0.9_sample_missing.txt -e 0 -t "Sample_missing_rate" -s  "Imputed_and_filtered_with_GP>=0.9|Average_missing_rate:$avg_miss_GP9_sam" -x "Missing_rate"
Rscript $SCRIPT_PATH/histogram.R  -i GP_0.8_sample_missing.txt -e 0 -t "Sample_missing_rate" -s  "Imputed_and_filtered_with_GP>=0.8|Average_missing_rate:$avg_miss_GP8_sam" -x "Missing_rate"

date
# step 4: evaluate imputation accuracy with random masking of 3% of genotyped data as missing
echo  "step 4: evaluate imputation accuracy with random masking of 3% of genotyped data as missing"
if [ $ref_available == "Y" ] || [ $ref_available == "y" ]; then
    sh $SCRIPT_PATH/imputation/run.sh $OVERLAPPEDVCF 0.05 $beagle $REFPANEL
else
    sh $SCRIPT_PATH/imputation/run.sh $IMPINPUT 0.05 $beagle
fi

perl -e '$SCRIPT_PATH=shift; @fs=<imp_eval/*.tsv>; foreach $f(@fs){$cmd="sh $SCRIPT_PATH/imputation/summarize.sh $f >${f}_AF.txt; sh $SCRIPT_PATH/imputation/summarize_v2.sh $f"; print $cmd, "\n"; system($cmd)}' $SCRIPT_PATH

# plot imputation accuracy per allele frequency range
ls imp_eval/*AF.txt | parallel -j 1 Rscript $SCRIPT_PATH/plot_imputation_accuracy_AF.R {}

# plot general imputation accuracy based on GP
ls imp_eval/*sum.table.csv | parallel -j 1 Rscript $SCRIPT_PATH/plot_imputation_accuracy_sum_table.R

# convert pdf to jpeg
echo " convert pdf to jpeg"

perl -e '@fs=<*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'
perl -e '@fs=<imp_eval/*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'

date
echo "Done"
