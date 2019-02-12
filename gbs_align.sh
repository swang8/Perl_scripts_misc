## QC
perl -MCwd -ne 'chomp; @t=split /\s+/,$_; $h{$t[1]}=$t[0]; END{$dir=getcwd(); mkdir($o) unless -d $o; $s="/home/shichen.wang/Tools/NGSQCToolkit_v2.3.3/QC/IlluQC.pl"; @arr= grep{/R1/} keys %h;  foreach $f(@arr){$f2=$f; $f2=/home/wangscs/R1/R2/; if(exists $h{$f2}){print "perl $s -pe $f $f2 2 5 \n"}else{print "perl $s -se $f 1 5 \n"}   } }' fastq.list  >qc.cmds
date
echo "start QC"
perl  /home/wangsc/pl_scripts/cmd_process_forker.pl -c qc.cmds --CPU 10
echo "finish QC"

perl -MFile::Basename -ne 'chomp; @t=split /\s+/,$_; push @{$h{$t[0]}}, $t[1]; END{foreach $acc(keys %h){%fs=map{$_, 1}@{$h{$acc}}; @fs_1=grep{/R1/}@{$h{$acc}}; foreach $f(@fs_1){$f2=$f; $f2=/home/wangscs/R1/R2/; $filtered_1 = dirname($f) . "/IlluQC_Filtered_files/".basename($f)."_filtered"; $filtered_2=dirname($f2) . "/IlluQC_Filtered_files/".basename($f2)."_filtered";  $s=dirname($f2) . "/IlluQC_Filtered_files/". basename($f). "_".basename($f2)."_unPaired_HQReads"; if(-e $f2){push @{$g{$acc}}, $filtered_1.",".$filtered_2; push @{$g{$acc}},$s unless (! -e $s) or (-z $s) }else{push @{$g{$acc}}, $f} }  }  foreach $k(keys %g){print join("\t", $k, @{$g{$k}}), "\n"}   }' fastq.list  >fastq.list_qc

## Alignment
REF=/home/wangsc/ref_data/wheat_concate/wheat_all_chr_ref_3B-splited.fa
REFINDEX=/home/wangsc/ref_data/wheat_concate/wheat_all_chr_ref_3B-splited.fa
export REF
export REFINDEX
perl -ne 'chomp; @t=split /\s+/,$_; $cmd="perl /home/wangsc/pl_scripts/align.pl -acc $t[0] -reads ". join(" ", @t[1..$#t]) . " -ref $ENV{REF} -refindex $ENV{REFINDEX} -outdir Alignments -MAQ 5 -CPU 5 -bowtie2 " . `which bowtie2`; print $cmd, "\n"' fastq.list_qc  >align.cmds

date
echo "start Alignment"
perl  /home/wangsc/pl_scripts/cmd_process_forker.pl -c align.cmds --CPU 8
echo "finish Alignment"
date

## Processing
perl -ne 'chomp; @t=split /\s+/,$_; $cmd="perl /home/wangsc/pl_scripts/process_GBS.pl -acc $t[0] -reads ". join(" ", @t[1..$#t]) . " -ref $ENV{REF} -refindex $ENV{REFINDEX} -outdir Alignments -MAQ 5 -CPU 5 -bowtie2 " . `which bowtie2`; print $cmd' fastq.list_qc  >process.cmds
date
echo "start Proc"
perl /home/wangsc/pl_scripts/cmd_process_forker.pl -c process.cmds --CPU 20
date
echo "finish Proc"
## Calling variations
mkdir Variations
dict=`perl -e '$f=shift; $f=/home/wangscs/\.fa$/\.dict/; print $f'`
perl -ne '@bams=<Alignments/*QC.bam>; if(/SN:(\S+)/){$chr=$1;  $cmd="perl  /home/wangsc/pl_scripts/unifiedgenotyper.pl -ref $ENV{REF} -out_prefix Variations/RAW_VAR_${chr} -region $chr -bam " . join(" ", @bams); print $cmd, "\n"; }'  $dict >call-var.cmds
date
echo "start Calling var"
perl /home/wangsc/pl_scripts/cmd_process_forker.pl -c call-var.cmds --CPU 5
date
echo "finish Calling var"
