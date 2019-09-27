r1=`ls *R1*fastq.gz`
echo "R1: " $r1

for f in $r1; do
  r2=`perl -e '$f=shift; $f=~s/R1/R2/; print $f' $f`
  echo $r2
  java trimmomatic.jar $r1 $r2  
done
