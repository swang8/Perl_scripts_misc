## perform imputation repeatedly to evalue the accuracy
module load parallel

ORIG_VCF=$1
REF_PANEL=$2
PROBABILITY=$3
cycles=10

beagle="/home/shichen.wang/Tools/beagle.21Jan17.6cc.jar"

chrs=$(perl -ne 'next if /\#/; $h{$1}=1 if /^(\S+)/; END{print join(":", sort{$a cmp $b} keys %h), "\n"}' ${ORIG_VCF})

# only use one chr. Comment the following three lines if want to use ALL chrs.
chrs=$(perl -e '$f=shift; print ((split(/:/, $f))[0], "\n")' $chrs)
perl -e '($vcf, $chr)=@ARGV; open(IN, $vcf) or die $!; while(<IN>){if(/\#/){print $_ ;next} $f=$1 if /^(\S+)/; print $_ if $f eq $chr}' $ORIG_VCF $chrs  >${ORIG_VCF}_chr.vcf
ORIG_VCF=${ORIG_VCF}_chr.vcf

###
if [ ! -d imp_eval_ref_panel ];  then mkdir imp_eval_ref_panel; fi
for i in `seq 1 $cycles`; do
  date
  echo $i
  # generate randome mutated 
  perl /home/shichen.wang/pl_scripts/imputation/generate_random_na.pl  $ORIG_VCF  $PROBABILITY 1>na.vcf 2>na.loci.txt

  # run beable 
  rm ./na.imputed*
  perl -e '$beagle = shift; $chr_str=shift;  @chrs=split /:/, $chr_str;  foreach $chr(@chrs){$cmd="java -jar $beagle  gtgl=na.vcf ref=$REF_PANEL chrom=$chr  nthreads=3 gprobs=true out=na.imputed_$chr"; print $cmd, "\n"}' $beagle $chrs  |parallel -j 3
  perl -e '$chr_str=shift;  @chrs=split /:/, $chr_str;  foreach $chr(@chrs){$f="na.imputed_${chr}.vcf.gz";  open(F, "zcat $f |") or die; while(<F>){print $_ unless /^\#/} close F}' $chrs >na.imputed.vcf
  ##java -jar $beagle  gtgl=na.vcf nthreads=10 gprobs=true out=na.imputed
  ## unzip the output
  ##gunzip na.imputed.vcf.gz
  
  # evaluate the imputed genotype
  perl /home/shichen.wang/pl_scripts/imputation/evaluate_concordancy.pl $ORIG_VCF na.vcf na.loci.txt na.imputed.vcf  >imp_eval_ref_panel/imputation_eval.${i}.tsv

done
  
