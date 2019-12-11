./agseq_vcf_processing_ref_panel.sh                                                                 0000775 �   ���   ���00000016470 13461662232 023302  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           module load parallel

# suppose a list of vcf files were provided
vcfs=$@

REFPANEL=${vcfs[0]} # the first vcf should the the ref panel

unset vcfs[0]

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
perl ~/pl_scripts/impute_miss_with_ref_panel.pl  $IMPINPUT $REFPANEL $beagle

OVERLAPPEDVCF=${IMPINPUT/.vcf/_overlapped.vcf}

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
sh ~/pl_scripts/imputation/run.sh $OVERLAPPEDVCF 0.03

perl -e '@fs=<imp_eval/*.tsv>; foreach $f(@fs){$cmd="sh /home/shichen.wang/pl_scripts/imputation/summarize.sh $f >${f}_AF.txt; sh /home/shichen.wang/pl_scripts/imputation/summarize_v2.sh $f"; print $cmd, "\n"; system($cmd)}'

# plot imputation accuracy per allele frequency range
ls imp_eval/*AF.txt | parallel -j 1 Rscript /home/shichen.wang/pl_scripts/plot_imputation_accuracy_AF.R {}

# plot general imputation accuracy based on GP
ls imp_eval/*sum.table.csv | parallel -j 1 Rscript /home/shichen.wang/pl_scripts/plot_imputation_accuracy_sum_table.R

# convert pdf to jpeg

perl -e '@fs=<*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'
perl -e '@fs=<imp_eval/*.pdf>; foreach $f(@fs){$jpeg=$f; $jpeg=~s/pdf$/jpeg/;  $cmd="convert -density 400 -quality 100 $f $jpeg"; print $f, "\n"; system($cmd)}'
                                                                                                                                                                                                        ./agseq_vcf_processing.sh                                                                           0000775 �   ���   ���00000016235 13461660774 021277  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           module load parallel

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
                                                                                                                                                                                                                                                                                                                                                                   ./align.pl                                                                                          0000775 �   ���   ���00000022664 13451157275 016177  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
use File::Basename;
use Getopt::Long;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;

my $sUsage = qq(
perl $0
-acc       Accession name
-reads     provide pairend reads (separate with comma) and/or single-end reads:  R1.fq,R2.fq  and/or single.fq
-ref       reference in fasta format
-refindex  bowtie2 index basename
-outdir    The directory for output
-MAQ       mapping quality cutoff, default is 0
-CPU       number of CPUs that will be used to run bowtie2
-bowtie2   The path to executable bowtie2: ie, /home/DNA/Tools/bowtie2/bin/bowtie2
);

##
# predefined 
my $samtools_bin = `which samtools`;
#my $samtools_bin = "samtools ";
my $picard_dir  = "/software/easybuild/software/picard/1.56-Java-1.7.0_80/";
my $GATK_jar = "~/Tools/GenomeAnalysisTK-2.2-8-gec077cd//GenomeAnalysisTK.jar ";

my (@read_files, $ref_fasta, $ref_index, $accession_name);
my ( $outdir, $MAX_THREADS) = ("./", 1); # default values
my $bowtie2_exec = `which bowtie2`; chomp $bowtie2_exec;
my $maq_cutoff = 0;

GetOptions('reads=s{1,}' => \@read_files,
					 'ref=s'       => \$ref_fasta,
					 'refindex=s'  => \$ref_index,
					 'bowtie2=s'   => \$bowtie2_exec,
					 'outdir=s'    => \$outdir,
					 'acc=s'       => \$accession_name,
					 'CPU=i'      => \$MAX_THREADS,
					 'MAQ=i'	=>\$maq_cutoff
					 );
die $sUsage unless (defined $ref_fasta and defined $ref_index);
die $sUsage unless @read_files > 0;

mkdir($outdir) if $outdir=~/\S/;

my @pair_reads = ([], []); 
my @single_reads;
map{
	chomp;
	my @p = split /,/, $_;
	if(@p == 2){
		push @{$pair_reads[0]}, $p[0];
		push @{$pair_reads[1]}, $p[1];
	}
	else{
		push @single_reads, $p[0]
	}
} @read_files;

## bt2 alignment
my $sam_file = $outdir . "/" .$accession_name . ".sam";
run_bowtie2($bowtie2_exec,$ref_index, $outdir, $accession_name, \@pair_reads, \@single_reads);
print_time_stamp("Finished alignment for accession $accession_name. The sam file is $sam_file\n");
###STOP
exit 0; ## stop here

## Processing steps
# samtobam
print_time_stamp("Convert SAM to BAM");
my $bam_file = $sam_file;
$bam_file =~ s/sam/bam/;
samTobam($sam_file);
&get_stat($bam_file);

## QC
print_time_stamp("\tStart removing low mapping Quality reads in bam file ......");
my $qc_bam = dirname($bam_file) . "/" . basename($bam_file, ".bam") . "_QC.bam";
print join("\t", $qc_bam), "\n";
&quality_filter($bam_file, $maq_cutoff);

index_bam_files($qc_bam);
#


## sort bam files
print_time_stamp("\tStart sorting bam file ......");
sort_bam_files($qc_bam);
my $sorted_bam = dirname($qc_bam) . "/". basename($qc_bam, ".bam") . "_sorted.bam";
print join("\t", $sorted_bam), "\n";
print_time_stamp("\tFinish sorting bam file ......");

# index bam files
print_time_stamp("\tStart indexing bam file ......");
index_bam_files($sorted_bam);
print_time_stamp("\tFinish indexing bam file ......");

#addRG
#print_time_stamp("add RG to bam");
#my $bam_addRG = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_addRG.bam";
#addRG($sorted_bam);
#print_time_stamp("\tFinished adding RG to bam file ......");
#


# realignment, two steps
print_time_stamp("\tStart realignment of bam file ......");
GATK_realignment($sorted_bam);
my $realigned_bam = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_realigned.bam";
print join("\t", $realigned_bam), "\n";
print_time_stamp("\tFinish realignment of bam file ......");


# duplicate marking
print_time_stamp("\tStart removing duplicates in bam file ......");
picard_duplicate_marking($realigned_bam);
my $rmdup_bam = dirname($realigned_bam) . "/" . basename($realigned_bam, ".bam") . "_rmDup.bam";
print join("\t", $rmdup_bam), "\n";
print_time_stamp("\tFinish removing duplicates in bam file ......");

# reindex
print_time_stamp("\tStart reindexing bam file ......");
index_bam_files($rmdup_bam);
print_time_stamp("\tFinish reindexing bam file ......\n");
sleep(60);
print_time_stamp("Finished all processing steps for accession $accession_name");

## Subroutines

sub quality_filter
{
  my $file = shift;
  my $maq = shift;
  my $out = dirname($file) . "/" . basename($file, ".bam") . "_QC.bam";
  open(IN, "$samtools_bin view -h -q $maq $file |") or die $!;
  open(OUT, "|$samtools_bin view -Sb - >$out") or die $!;
  while(<IN>){
    if(/^\@/){print OUT $_; next}
    my @t = split /\s+/,$_; 
    print OUT $_ if $t[6] eq '*' or $t[6] eq '=';
  }
  close IN;
  close OUT;
}

sub rm_overfloat
{
  my $file = shift;
  my $rm_file = dirname($file) . "/" . basename($file, ".bam") . "_rm.bam";
  my $MAX = 2**29 - 1;
  open(IN , "$samtools_bin view -h $file |") or die;
  open(OUT, "|$samtools_bin view -Sb - >$rm_file") or die;
  while(<IN>){
    if(/^\@/){print OUT $_; next}
    my @t = split /\s+/, $_;
    print OUT if $t[3] < $MAX and $t[7] < $MAX and $t[8] < $MAX;
  }

  close IN;
  close OUT;
  return $rm_file;
}


sub run_bowtie2
{
	# run_bowtie2($bowtie2_exec, $outdir, $accession_name, \@pair_reads, \@single_reads);
	my ($bowtie2, $refindex, $out, $acc, $pair_ref, $single_ref) = @_;
	print_time_stamp("Start runing bowtie2 alignemtn for acc $acc");
	my $cmd = "$bowtie2 -x $refindex ";
	if(@{$pair_ref->[0]} > 0){
		$cmd .=  " -1 ". join(",", @{$pair_ref->[0]}) . " -2 ". join(",", @{$pair_ref->[1]});
	}
	
	if (@{$single_ref} > 0){
		$cmd .= " -U ".join(",", @$single_ref);
	}
	
	my $sam = $outdir . "/" .$acc . ".sam";
	my $log = $outdir . "/". $acc . "_align.log";
	
	$cmd .= " --rg-id $acc --very-sensitive-local -p $MAX_THREADS -S $sam 2>$log";

	
	print_time_stamp("\t$cmd");
	die if system($cmd);
	return $sam;
}


sub samTobam
{
	my $file = shift or die $!;
	my $bam = $file;
	$bam=~s/sam$/bam/;
	my $cmd = "$samtools_bin  view -Shb $file  >$bam";
	die "$cmd failed !\n" if system($cmd);
	return $bam;
 }

sub picard_duplicate_marking
{
	my @realn_bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $merics_file = $_ . ".metrics";
		my $out = dirname($_) . "/" . basename($_, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx10G -jar $picard_dir/MarkDuplicates.jar I=$_ O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
		push @picard_cmds, $cmd;
	}@realn_bams;
	
	run_parallel_jobs(\@picard_cmds, $MAX_THREADS);
	
	return @rmdup_bams;
}


sub GATK_realignment
{
	my @sorted_bams = @_;
	my @generate_interval_cmds;
	my @intervals;
	map {
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
	
	run_parallel_jobs(\@generate_interval_cmds, $MAX_THREADS);
	
	my @realigned_bams;
	my @realign_cmds;
	map{
		my $interval = $_ . ".intervals";
		my $realn_bam = dirname($_) . "/" . basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx10G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		push @realign_cmds, $cmd;
	} @sorted_bams;

	run_parallel_jobs(\@realign_cmds, $MAX_THREADS);
	return @realigned_bams;
}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . "index " . $_}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub reassign_mapping_quality
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $default_mapping_quality = 100;
	foreach my $bam (@bam_files)
	{
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
	}
		
}


sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_prefix = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . "sort -m 3000000000 $bam $sorted_prefix";
		push @sort_cmds, $cmd #unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub sort_bam_files_picard
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_bam = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted.bam";
		push @return , $sorted_bam;
		my $cmd = "java -jar $picard_dir/SortSam.jar I=$bam O=$sorted_bam SO=coordinate";
		push @sort_cmds, $cmd;
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub addRG
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		my $id = basename($bam, ".bam");
		my $out = dirname($bam). "/" . $id . "_addRG.bam";
		push @return, $out;
		my $cmd = "java -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$id LB=SeqCap ID=$id VALIDATION_STRINGENCY=SILENT";
		push @cmds, $cmd;
	}
	run_parallel_jobs(\@cmds, $MAX_THREADS);
	return @return;
}


sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		print_time_stamp("\nRunning command: $cmd\n");
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}


sub print_time_stamp
{
        my $comments = shift;
        my $time = localtime();
        print STDERR $time, "\t", $comments, "\n";
}

sub help
{
	print $sUsage;
	exit;
}
	


sub get_stat {

  my @bams = @_;
  foreach my $f( @bams){
    my $stat = $f. ".aln.stat.txt";
    my $cmd = "$samtools_bin flagstat $f >$stat";
    die "$cmd failed!\n" if system($cmd);
  }

}

                                                                            ./generate_bsub.pl                                                                                  0000775 �   ���   ���00000017520 13457630732 017705  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
use Getopt::Long;
use File::Basename;

my $fastq_file; 
my $qc_pl;
my $aln_pl;
my $call_pl;
my $REF;
my $REFINDEX;
my $num_jobs;
my $job_name;

GetOptions (
"fq_List=s"   => \$fastq_file,
"numJobs=i" => \$num_jobs,
"jobName=s" => \$job_name,
"qc_pl=s" => \$qc_pl,
"aln_pl=s"  => \$aln_pl,
"call_pl=s" => \$call_pl,
"ref=s"     => \$REF,
"refindex=s" => \$REFINDEX
);

sub help {
print qq(
perl $0
  -fq_list fastq_list.txt  # list of fastq files, first column is the accession name, second column is the full path to the fastq file (fastq or gzfastq);
  -numJobs  10             # how many jobs to be submitted to the HPC
  -jobName  myJob          # The name of job
  -aln_pl   /home/$ENV{USER}/pl_scripts/align.pl
  -call_pl  /home/$ENV{USER}/pl_scripts/unifiedgenotyper.pl
  -ref      /home/$ENV{USER}/scratch_fast/ref_data/Dgenome/Dgenome.fa
  -refindex /home/$ENV{USER}/scratch_fast/ref_data/Dgenome/Dgenome_bt2_index

Once the bsub scripts are generated, run "ls *.bsub |perl submit_sequential_jobs.pl" to submit all the jobs.
); 
}

unless ($fastq_file and $REF and $REFINDEX) {
  &help();
  exit;
}

open (IN, $fastq_file) or die "Error: can not open $fastq_file\n";

$num_jobs = 10 unless $num_jobs;

$job_name = "bsubjob" unless $job_name;

my %h;
while(<IN>){
  chomp;
  my @t = split /\s+/,$_;
  unless ($t[1] =~ /^\//){die "Error: require absolute path for fastq files\n"}
  map{ $h{$_} = $t[0] }@t[1..$#t];
}
close IN;
time_stamp("done reading fastq list file");
#
$qc_pl = "/home/$ENV{USER}/Tools/NGSQCToolkit_v2.3.3/QC/IlluQC.pl" unless defined $qc_pl;
my @arr = grep{!/R2/} keys %h;

my @params; 
foreach my $f (@arr) {
  my $f2=$f; 
  $f2=~s/R1/R2/; 
  my $folder = dirname($f);
  my $qc_folder = $folder . "/QC";
  my $acc = $h{$f};
  mkdir $qc_folder unless -d $qc_folder;
  if(exists $h{$f2}) {
    #push @params, "-pe $f $f2 2 5";
    my $cmd="java -jar \$EBROOTTRIMMOMATIC/trimmomatic-0.38.jar PE -threads 4 $f $f2 $qc_folder/${acc}_F.fq.gz  $qc_folder/${acc}_FU.fq.gz $qc_folder/${acc}_R.fq.gz $qc_folder/${acc}_RU.fq.gz ILLUMINACLIP:\$EBROOTTRIMMOMATIC/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36";
    push @params, $cmd;
  }
  else{
    #push @params, "-se $f 1 5"
     my $cmd="java -jar \$EBROOTTRIMMOMATIC/trimmomatic-0.38.jar SE -threads 4 $f  $qc_folder/${acc}_F.fq.gz  ILLUMINACLIP:\$EBROOTTRIMMOMATIC/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36";
     push @params, $cmd;
  }   
}
##
my $header = qq(#!/bin/bash
#
# See "man bsub" for more information on rusage
#
#BSUB -W 70:05                    # wall-clock time (hrs:mins)
#BSUB -L /bin/bash                # login shell    
#BSUB -n 1                        # number of tasks in job
#BSUB -R "span[ptile=1]"          # run one MPI task per node
#BSUB -R "rusage[mem=8000]"     # memory to reserve, in MB
#BSUB -J myjob                    # job name
#BSUB -o myjob.%J.%I.out             # output file name in which %J is replaced by the job ID
#BSUB -e myjob.%J.%I.err             # error file name in which %J is replaced by the job ID

module load zlib/1.2.8-intel-2015B
module load Java/1.8.0_181
module load   SAMtools/1.3-intel-2016a
export PERL5LIB="/home/wangsc/perl5/lib/perl5/x86_64-linux-thread-multi___/"  # modify this path to reflect your own setup
);


my $qc_header = $header;
# Generate bsub job script for QC
my $qc_bsub = "0.qc.bsub";
open(QB, ">$qc_bsub") or die $!;

my $num_param = int ( (scalar @params) / $num_jobs ) + 1;
$num_param++ if (scalar @params) % $num_jobs ;
$qc_header =~ s/-J\s+myjob/"-J ". $job_name . "_QC[1-$num_jobs]"/e;
$qc_header =~ s/myjob/$job_name . "_QC"/eg;
$qc_header =~ s/-n 1/-n 4/;
$qc_header =~ s/ptile=1/ptile=4/;
print QB $qc_header, "\nmodule load Trimmomatic/0.38-Java-1.8.0\ndate\n";
print STDERR '$num_jobs: ', $num_jobs, "\n";
print STDERR '$num_param: ', $num_param, "\n";
foreach my $ind (1 .. $num_jobs){
  my $start = ($ind - 1) * $num_param;
  my $end = $start + $num_param - 1;
  $end = $#params if $end > $#params;
  my $cmd = join("\n", @params[$start .. $end]);
  print QB "if [ \$LSB_JOBINDEX  ==  $ind ]; then\n", $cmd, "\nfi\n\n";
  print STDERR "if [ \$LSB_JOBINDEX  ==  $ind ]; then\n", $cmd, "\nfi\n\n";
  if ($start >= $#params or $end >= $#params){ last}
}




print QB "date\n echo \"Done \$LSB_JOBINDEX\"\n";
close QB;
time_stamp("generated $qc_bsub");

## Generate bsub job script for Alignment
my $aln_header = $header;
$aln_header =~ s/-n\s+\d+/-n 10/;
$aln_header =~ s/ptile=\d+/ptile=10/;
$aln_header =~ s/mem=\d+/mem=2000/;
my $aln_bsub = "1.aln.bsub";
open(ALN, ">$aln_bsub") or die $!;

my %acc_qc;
foreach (@params){
  my @p = split /\s+/,$_;
  my @fs = / PE /?@p[8..11]:$p[7];
  my $dir = dirname($fs[0]);
  my $acc = $h{$p[6]};
  if(@fs == 1){push @{$acc_qc{$acc}},  $fs[0]; next}
  my @filtered = @fs[0,2];
  #my $single_HQ = $dir . "/IlluQC_Filtered_files/" . basename($fs[0]) . "_" . basename($fs[1]) . "_unPaired_HQReads";
  push @{$acc_qc{$acc}}, join(",", @filtered);
  #push @{$acc_qc{$acc}}, $single_HQ if -e $single_HQ and not -z $single_HQ;
}
$aln_pl = "/home/$ENV{USER}/pl_scripts/align.pl" unless defined $aln_pl;
$REF="/home/$ENV{USER}/scratch_fast/Projects/GBS/wheat/ref_data/wheat_concate/Dgenome/Dgenome.fa" unless $REF;
$REFINDEX="/home/$ENV{USER}/scratch_fast/Projects/GBS/wheat/ref_data/wheat_concate/Dgenome/Dgenome.fa" unless $REFINDEX;
my $outdir = "Alignments"; mkdir($outdir) unless -d $outdir;
my $b2 = `module load Bowtie2/2.3.4.2-foss-2018b; which bowtie2`; 
my @aln_cmds;
map{
  my $acc = $_;
  my @fs = @{$acc_qc{$acc}};
  push @aln_cmds, "perl $aln_pl -acc $acc -reads " . join(" ", @fs) . " -ref $REF -refindex $REFINDEX -outdir $outdir -MAQ 5 -CPU 10 -bowtie2 $b2";
}keys %acc_qc;

my $start = 0;
my $index = 0;
my $total = int ((scalar @aln_cmds) / 10);
$total ++ if (scalar @aln_cmds) / 10;

$aln_header =~ s/myjob/$job_name."_ALN[1-$total]"/e;
$aln_header =~ s/myjob/$job_name."_ALN"/eg;
print ALN  $aln_header, "\nmodule load Bowtie2/2.3.4.2-foss-2018b\ndate\n";
while($start <= $#aln_cmds){
  $index ++;
  print ALN "if [ \$LSB_JOBINDEX == $index ]; then\n";
  my $end = $start + 9;
  $end = $#aln_cmds if $end > $#aln_cmds;
  print ALN join("\n", @aln_cmds[$start .. $end]), "\nfi\n\n";
  last if $end >= $#aln_cmds;
  $start = $end + 1; 
}
print ALN "date\necho \"done \$LSB_JOBINDEX\"\n";
close ALN;
time_stamp("generated $aln_bsub");
## generate bsub job script for processing
my $proc_bsub = "2.proc.bsub";
open(PB, ">$proc_bsub") or die $!;
open(IN, $aln_bsub) or die $!;
while(<IN>){
  s/-n\s+\d+/-n 1/;
  s/ptile=\d+/ptile=1/;
  s/mem=\d+/mem=8000/;
  s/align.pl/process_v2.pl/;
  s/_ALN/_PROC/ if /^\#/;
  print PB $_;
}
close IN;
close PB;
time_stamp("generated $proc_bsub");
## genearte bsub job script for calling variations
$call_pl = "/home/$ENV{USER}/pl_scripts/haplotypecaller.pl" unless $call_pl;
my $call_bsub = "3.call.bsub";
open (CB, ">$call_bsub") or die $!;
my $call_header = $header;
$call_header =~ s/-n\s+\d+/-n 1/;
$call_header =~ s/ptile=\d+/ptile=1/;

my @chrs = get_chrs_from_fai($REF.".fai");
my $t = scalar @chrs;
$call_header =~ s/myjob/$job_name."_VAR[1-$t]"/e;
$call_header =~ s/myjob/$job_name."_VAR"/eg;
print CB $call_header, "\ndate\n";
my $var_dir = "Variations"; mkdir($var_dir) unless -d $var_dir;
my @bams = ("$outdir/*QC.bam");
foreach my $ind (0 .. $#chrs){
  my $job = $ind + 1;
  print CB "if [ \$LSB_JOBINDEX == $job ]; then\n ";
  print CB "perl $call_pl  -ref $REF -out_prefix Variations/$chrs[$ind] -region $chrs[$ind] -bam " . join(" ", @bams), "\n";
  print CB "fi\n\n";
}

print CB "date\necho \"done \$LSB_JOBINDEX\"\n";
close CB;
time_stamp("generated $call_bsub");

##
sub get_chrs_from_fai {
  my $f = shift;
  open(IN, $f) or die $!;
  my @return;
  while(<IN>){
    push @return, $1 if /^(\S+)/;
  }
  close IN;
  return @return;
}

sub time_stamp{
  my $s = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $s, "\n";
}
                                                                                                                                                                                ./haplotypecaller.pl                                                                                0000775 �   ���   ���00000025753 13451157275 020277  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
#use lib '/homes/wangsc/perl_lib'; # for beocat;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;
use File::Basename;
use Getopt::Long;

my $sUsage = qq(
###########################################################################################################################
	Suppose we have bam files for each accessions separately (sample1.bam, sample2.bam, ...), 
	call variations using GATK based on these bam files.
	Steps:
	1. sort each bam file (samtools sort) + index the bam file (samtools index)
	2. realignment (GATK, -T RealignerTargetCreator + -T IndelRealigner)
	3. MarkDuplicates for realign bam file (picard, MarkDuplicates.jar) + index the bam file (samtools index)
	4. Base quality recalibration (GATK, -T CountCovariates) + index for recalibrated bam file (samtools index)
	5. Calling variations (GATK, -T HaplotypeCaller)
	
	Usage:	
	perl $0
	-ref                reference fasta file
	-out_prefix         output prefix for variation file
	-region             specific region for variation calling, chr_1:12345-876812
	-dcov               mean coverage, default: 200
	-bam                processed bam files: 1.bam 2.bam 3.bam
	-gatk		    The path to the gatk jar, i.e.,  /home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar
        -params		    Other parameters for GATK, such as "--output_mode EMIT_ALL_SITES"
	-help               print this message
	
	example:
	perl $0 -ref ref.fasta  -out_prefix Var/test -region 1AL:1-9607790  -bam sample*.bam
	
	SW\@KSU Dec.01.2012
###########################################################################################################################

);

die $sUsage unless @ARGV;

# predefined 
#my $samtools_bin = "/homes/bioinfo/bioinfo_software/samtools/samtools ";
my $bamutil = "/home/wangsc/Tools/bamUtil/bin/bam ";
#check_exec($bamutil);
my $samtools_bin = `module load SAMtools/0.1.19-intel-2015B; which samtools`;
chomp $samtools_bin;
#check_exec($samtools_bin);
my $picard_dir  = "/software/easybuild/software/picard/1.56-Java-1.7.0_80/";
##my $GATK_jar = "/home/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $GATK_jar = "/home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar ";
my ($ref_fasta, $out_prefix, $region, $MAX_THREADS, @bam_files, $help, $dcov, $gatk_params);
$MAX_THREADS = 1;
my $TMP;
GetOptions(
'ref=s'        =>	\$ref_fasta,
'nt=i'         =>	\$MAX_THREADS,
'region=s'     =>	\$region,
'out_prefix=s' =>       \$out_prefix,
'tmp=s'        =>       \$TMP,
'dcov=i'       =>       \$dcov,
'bam=s{1,}'    =>	\@bam_files,
'gatk=s'       =>       \$GATK_jar,
'params=s'     =>       \$gatk_params,
'help'         =>	sub{help()}
);


die $sUsage unless (defined $ref_fasta and defined $out_prefix and (@bam_files >=1) );

$dcov = 200 unless $dcov;
$GATK_jar = "/home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar " unless $GATK_jar; 

#print join("\n", ($ref_fasta, $out_prefix, $MAX_THREADS, @bam_files)), "\n"; exit;

print_time_stamp("Start GATK pipeline .....");
## index ref fasta
unless (-e $ref_fasta.".fai"){
	print_time_stamp("\tIndexing reference fasta file " . $ref_fasta);
	die "Index reference fasta failed \n" if system($samtools_bin . " faidx $ref_fasta");
	print_time_stamp("\tFinish indexing reference fasta file");
}
#
#print join("\t", @bam_files), "\n";
#
## add RG to bam file
#print_time_stamp("\tAdd RG to bam files ......");
#my @bams_addRG = map {basename($_, ".bam") . "_addRG.bam";} @bam_files;
#print join("\t", @bams_addRG), "\n";
##addRG(@bam_files);
#print_time_stamp("\tFinished ......");	
#
## sort bam files
#print_time_stamp("\tStart sorting bam files ......");
#my @sorted_bams = map {basename($_, ".bam") . "_sorted.bam";} @bams_addRG;
#print join("\t", @sorted_bams), "\n";
##sort_bam_files(@bams_addRG);
#print_time_stamp("\tFinish sorting bam files ......");	
#
## reassign mapping quality
#print_time_stamp("\tStarted reassigning mapping quality ......");
#my @bams_MQ= map {basename($_, ".bam") . "_MQ.bam"} @sorted_bams;
#print join("\t", @bams_MQ), "\n";
##reassign_mapping_quality_parallel($MAX_THREADS, @sorted_bams);
#print_time_stamp("\tFinished reassigning mapping quality ......");
#
## index bam files
#print_time_stamp("\tStart indexing bam files ......");
##index_bam_files(@sorted_bams);
#print_time_stamp("\tFinish indexing bam files ......");
#
## realignment, two steps
#print_time_stamp("\tStart realignment of bam files ......");
#my @realigned_bams = map {basename($_, ".bam") . "_realigned.bam";} @sorted_bams;
#print join("\t", @realigned_bams), "\n";
##GATK_realignment(@sorted_bams);
#print_time_stamp("\tFinish realignment of bam files ......");
#
## duplicate marking
#print_time_stamp("\tStart removing duplicates in bam files ......");
#my @rmdup_bams = map {basename($_, ".bam") . "_rmDup.bam";} @realigned_bams;
#print join("\t", @rmdup_bams), "\n";
##picard_duplicate_marking(@realigned_bams);
#print_time_stamp("\tFinish removing duplicates in bam files ......");
#
## reindex
#print_time_stamp("\tStart reindexing bam files ......");
##index_bam_files(@rmdup_bams);
#print_time_stamp("\tFinish reindexing bam files ......");


# SNP and Indel calling
print_time_stamp("\tStart calling variations from bam files ......");
my $raw_variation_vcf = variation_calling_haplotypecaller($gatk_params, @bam_files);
print_time_stamp("\tFinish calling variations from bam files ......");

# Variant Quality Score Recalibration, VQSR (not implmented yet)
#print_time_stamp("\tStart Variant Quality Score Recalibration ......");
#VQSR($raw_variation_vcf);
#print_time_stamp("\tFinish Variant Quality Score Recalibration ......");


# Done
#print_time_stamp("Finish GATK pipeline except VQSR.....");

# Subroutines
sub VQSR 
{

}


sub variation_calling
{
	my @recal_bams = @_;
	my @params = map{"-I ".$_} @recal_bams;
	my $out = $out_prefix . "_raw.snps.indels.vcf";
	my $cmd = "java -jar $GATK_jar -T HaplotypeCaller -R $ref_fasta -nt 20 ". join(" ", @params) . " -o $out";
  	die "!!! $cmd failed\n" if system($cmd);
  
  	return $out;
}

sub variation_calling_haplotypecaller
{
	my $gatk_params = shift;
        my @recal_bams = @_;
        my @params = map{"-I ".$_} @recal_bams;
        my $out = $out_prefix . "_raw.snps.indels.vcf";
	my $basedir = dirname($out); mkdir($basedir) unless -d $basedir;
        my $cmd = "java -Xmx30G  -jar $GATK_jar -T HaplotypeCaller -R $ref_fasta ". join(" ", @params) . " " . (defined $region?"-L $region ":" ") . " -o $out" . " -drf BadMate -drf DuplicateRead -U ALLOW_N_CIGAR_READS";
        $cmd  = $cmd . " " .  $gatk_params if $gatk_params;

  	die "!!! $cmd failed\n" if system($cmd);

	return $out;
}


sub base_recalibration
{
	my @rmdup_bams = @_;
	my @recal_bams;
	
	map{
		my $grp = basename($_, ".bam") . ".grp";
		
		# Step 1. Generates recalibration table, -T BaseRecalibrator
		my $cmd_a = "java -Xmx3g -jar $GATK_jar -T BaseRecalibrator -I $_  -R $ref_fasta -o $grp";
	  
	  print_time_stamp("\nRunning command: $cmd_a\n");
	  die "!!!\t$cmd_a failed\n" if system($cmd_a);
	  
	  # Step 2. print reads,  -T PrintReads
	  my $out_bam = basename($_, ".bam") . "_recal.bam";
	  my $cmd_b = "java -jar $GATK_jar -T PrintReads -R $ref_fasta -nt $MAX_THREADS -I $_  -BQSR $grp -o $out_bam";
   
   print_time_stamp("\nRunning command: $cmd_b\n");
   die "!!!\t$cmd_a failed\n" if system($cmd_b);
   
   push @recal_bams, $out_bam;
	  
	}@rmdup_bams;
	
	return @recal_bams;
}


sub picard_duplicate_marking
{
	my @realn_bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $merics_file = $_ . ".metrics";
		my $out = basename($_, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/MarkDuplicates.jar I=$_ O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
		push @picard_cmds, $cmd;
	}@realn_bams;
	
	run_parallel_jobs(\@picard_cmds, $MAX_THREADS);
	
	return @rmdup_bams;
}


sub GATK_realignment
{
	my @sorted_bams = @_;
	my @generate_interval_cmds;
	my @intervals;
	map {
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
	
	run_parallel_jobs(\@generate_interval_cmds, $MAX_THREADS);
	
	my @realigned_bams;
	my @realign_cmds;
	map{
		my $interval = $_ . ".intervals";
		my $realn_bam = basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		push @realign_cmds, $cmd;
	} @sorted_bams;

	run_parallel_jobs(\@realign_cmds, $MAX_THREADS);
	return @realigned_bams;
}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . " index " . $_;}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub reassign_mapping_quality
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $default_mapping_quality = 100;
	foreach my $bam (@bam_files)
	{
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
	}
		
}

sub reassign_mapping_quality_parallel
{
	my $max = shift;
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $pm = new Parallel::ForkManager($max);
	foreach my $bam (@bam_files)
	{
		$pm->start and next;
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
		
		$pm->finish;
	}
	
	$pm->wait_all_children;	
}


sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_prefix = basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . "sort -m 3000000000 $bam $sorted_prefix";
		push @sort_cmds, $cmd unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub addRG
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		my $id = basename($bam, ".bam");
		my $out = $id . "_addRG.bam";
		push @return, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$id LB=SeqCap ID=$id";
		push @cmds, $cmd;
	}
	run_parallel_jobs(\@cmds, $MAX_THREADS);
	return @return;
}

sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		print_time_stamp("\nRunning command: $cmd\n");
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}


sub print_time_stamp
{
        my $comments = shift;
        my $time = localtime();
        print STDERR $time, "\t", $comments, "\n";
}

sub help
{
	print $sUsage;
	exit;
}

			
                     ./histogram.R                                                                                       0000664 �   ���   ���00000003457 13451166700 016655  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           library("optparse")
 
option_list = list(
  make_option(c("-i", "--input"), type="character", default=NULL, 
              help="dataset file name", metavar="character"),
  make_option(c("-e", "--header"), type="integer", default=0,
              help="contains header or not", metavar="character"),
  make_option(c("-x", "--xlab"), type="character", default=NULL,
              help="the labele for X axis", metavar="character"),
  make_option(c("-y", "--ylab"), type="character", default=NULL,
              help="the label for Y axis", metavar="character"),
  make_option(c("-t", "--title"), type="character", default=NULL,
              help="the label for Title", metavar="character"),
  make_option(c("-s", "--subtitle"), type="character", default="",
              help="the label for subtitle", metavar="character")
); 
 
opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$input)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

data = read.table(opt$input, header=(opt$header==1) )
print(head(data))

library(ggplot2)

col = colnames(data)
print(col[1])

p = ggplot(data) + geom_histogram(aes(x=array(data[, col[1]])))

if (! is.null(opt$title))  p = p + ggtitle(opt$title)
if (! is.null(opt$subtitle))  p = p + labs(subtitle=opt$subtitle)
if (! is.null(opt$xlab) )  p = p + xlab(opt$xlab)
if (! is.null(opt$ylab))  p = p + ylab(opt$ylab)

p = p + 
theme(
    plot.title = element_text(size=30, face="bold", hjust=0.5),
    plot.subtitle=element_text(size=12, hjust=0.5, face="italic"),
    axis.title.x = element_text(size=20, face="bold"),
    axis.title.y = element_text(size=20, face="bold")
    ) + 
scale_x_continuous(limits=c(-0.1, 1))

pdfout = paste(opt$input, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")
                                                                                                                                                                                                                 ./impute_miss.pl                                                                                    0000775 �   ���   ���00000005022 13451157275 017430  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
use lib '/home/wangsc/perl5/lib/perl5';
use File::Basename;
use Parallel::ForkManager;

my $sUsage = "perl $0  <in_vcf>  <beagle_jar> <file_for_ordering_markers, optional>\n";
my $in_vcf = shift or die $sUsage;
my $jar = shift or die $sUsage;

my $order_file = "";
$order_file = shift;
## $order_file = "/home/wangsc/scratch_fast/Projects/GBS/wheat/ref_data/wheat_CSS/All_chr_flowsort-contigs_mapped_on_Ensembl-ref.txt_replace_NonCaoncatenated" unless $order_file;

my $ordered_vcf = $in_vcf; 
$ordered_vcf = order_markers($order_file, $in_vcf) if  $order_file =~ /\S/;

impute_missing($ordered_vcf, $jar);

##
sub print_time_stamp {
  my $str = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $str;
}

sub order_markers {
  my $order = shift;
  my $vcf = shift;
  if (not defined $order){return $vcf}
  my %ctg_pos = get_contig_pos($order);
  my $ord_vcf = basename($vcf);
  if($ord_vcf=~/.vcf$/){$ord_vcf=~s/\.vcf$/_ordered\.vcf/;}else{$ord_vcf = $ord_vcf . ".ordered"}
  open(OUT, ">$ord_vcf") or die "can not open file $ord_vcf!!";
  open(IN, $vcf) or die $!;
  my @arr;
  while(<IN>){
    if(/^\#/){print OUT $_; next}
    chomp;
    my @t = split /\s+/,$_; 
    my ($ctg, $pos) = @t[0,1];
    next if $t[3]=~/[^ATGCN]/ or $t[4] =~ /[^ATGCN]/;
    next unless exists $ctg_pos{$ctg};
    $t[2] = join(":", @t[0,1]);
    $t[0] = $ctg_pos{$ctg}[0];
    $t[1] = $pos + $ctg_pos{$ctg}[1] - 1;
    push @arr, [@t];
  }
  
  map {
    print OUT join("\t", @$_), "\n";
  } sort{$a->[0] cmp $b->[0] or $a->[1] <=> $b->[1]} @arr;  

  close OUT; 
  close IN;
  return $ord_vcf;
}

sub get_contig_pos{
  my $order_file = shift;
  open(my $IN, $order_file) or die $!;
  my %return;
  while(<$IN>){
    chomp;
    my @t = split /\s+/,$_;
    $return{$t[0]} = [@t[1,2]]
  }
  close $IN;
  return %return;
}

sub impute_missing {
  my $vcf = shift;
  my @chrs = get_chr($vcf);
  @chrs = grep {/\d/} @chrs;
  my $jar = shift;
  my $pm = Parallel::ForkManager->new(4); ## max 4 threads
  LOOP:
  foreach my $chr (@chrs) {
    $pm->start and next LOOP; # do the fork
    my $out = $chr . "_imputed";
    my $cmd = "java -Xmx8G -jar $jar gtgl=$vcf out=$out  niterations=10 gprobs=true lowmem=true chrom=$chr";
    print STDERR $cmd, "\n";
    system($cmd);
    $pm->finish; # do the exit in the child process
  }
  $pm->wait_all_children;
}

sub get_chr{
  my $vcf = shift;
  open(IN, $vcf) or die $!;
  my %return;
  while(<IN>){
    next if /^\#/;
    my $chr = $1 if /^(\S+)/;
    $return{$chr}=1
  }
  close IN;
  return keys %return;

}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ./impute_miss_with_ref_panel.pl                                                                     0000664 �   ���   ���00000006342 13461657456 022510  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
use lib '/home/wangsc/perl5/lib/perl5';
use lib '/home/shichen.wang/perl5/lib/perl5';
use File::Basename;
use Parallel::ForkManager;

my $sUsage = "perl $0  <in_vcf> <ref_panel_vcf>  <beagle_jar> \n";
my $in_vcf = shift or die $sUsage;
my $ref_vcf = shift or die $sUsage;
my $jar = shift or die $sUsage;

my $order_file = shift || "";
## $order_file = "/home/wangsc/scratch_fast/Projects/GBS/wheat/ref_data/wheat_CSS/All_chr_flowsort-contigs_mapped_on_Ensembl-ref.txt_replace_NonCaoncatenated" unless $order_file;

my $ordered_vcf = $in_vcf; 
$ordered_vcf = order_markers($order_file, $in_vcf) if  $order_file =~ /\S/;

generate_overlapped_vcf($in_vcf, $ref_vcf);
impute_missing($ordered_vcf, $jar);

##
sub print_time_stamp {
  my $str = join(" ", @_);
  my $t = localtime(time);
  print STDERR $t, "\t", $str;
}

sub order_markers {
  my $order = shift;
  my $vcf = shift;
  if (not defined $order){return $vcf}
  my %ctg_pos = get_contig_pos($order);
  my $ord_vcf = basename($vcf);
  if($ord_vcf=~/.vcf$/){$ord_vcf=~s/\.vcf$/_ordered\.vcf/;}else{$ord_vcf = $ord_vcf . ".ordered"}
  open(OUT, ">$ord_vcf") or die "can not open file $ord_vcf!!";
  open(IN, $vcf) or die $!;
  my @arr;
  while(<IN>){
    if(/^\#/){print OUT $_; next}
    chomp;
    my @t = split /\s+/,$_; 
    my ($ctg, $pos) = @t[0,1];
    next if $t[3]=~/[^ATGCN]/ or $t[4] =~ /[^ATGCN]/;
    next unless exists $ctg_pos{$ctg};
    $t[2] = join(":", @t[0,1]);
    $t[0] = $ctg_pos{$ctg}[0];
    $t[1] = $pos + $ctg_pos{$ctg}[1] - 1;
    push @arr, [@t];
  }
  
  map {
    print OUT join("\t", @$_), "\n";
  } sort{$a->[0] cmp $b->[0] or $a->[1] <=> $b->[1]} @arr;  

  close OUT; 
  close IN;
  return $ord_vcf;
}

sub get_contig_pos{
  my $order_file = shift;
  open(my $IN, $order_file) or die $!;
  my %return;
  while(<$IN>){
    chomp;
    my @t = split /\s+/,$_;
    $return{$t[0]} = [@t[1,2]]
  }
  close $IN;
  return %return;
}

sub impute_missing {
  my $vcf = shift;
  my @chrs = get_chr($vcf);
  @chrs = grep {/\d/} @chrs;
  my $jar = shift;
  my $pm = Parallel::ForkManager->new(4); ## max 4 threads
  LOOP:
  foreach my $chr (@chrs) {
    $pm->start and next LOOP; # do the fork
    my $out = $chr . "_imputed";
    my $cmd = "java -Xmx8G -jar $jar gtgl=$vcf ref=$ref_vcf out=$out  niterations=10 gprobs=true lowmem=true chrom=$chr";
    print STDERR $cmd, "\n";
    system($cmd);
    $pm->finish; # do the exit in the child process
  }
  $pm->wait_all_children;
}

sub get_chr{
  my $vcf = shift;
  open(IN, $vcf) or die $!;
  my %return;
  while(<IN>){
    next if /^\#/;
    my $chr = $1 if /^(\S+)/;
    $return{$chr}=1
  }
  close IN;
  return keys %return;
}

sub generate_overlapped_vcf {
  my ($vcf, $ref) = @_;
  my %snps_in_ref = get_ids_from_vcf($ref);
  open (V, $vcf) or die $!;
  my $out = $vcf;
  $out = ~s/\.vcf$/_overlapped.vcf/;
  open(OUT, ">$out") or die $!;
  while(<V>){
    if(/\#/){print OUT $_; next}
    my @t = split /\s+/, $_;
    my $id = join(" ", @t[0,1]);
    print OUT $_ if exists $snps_in_ref{$id};
  }
  close V;
  close OUT;
}

sub get_ids_from_vcf {
  my $in = shift;
  my %return;
  open (IN, $in) or die $!;
  while(<IN>){
    next if /\#/;
    my @t = split /\s+/, $_;
    $return{join(" ", @t[0,1])}=1
  }
  close IN;
  return %return;
}
                                                                                                                                                                                                                                                                                              ./plot_imputation_accuracy_AF.R                                                                     0000664 �   ���   ���00000001261 13451166726 022326  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           args = commandArgs(trailingOnly=TRUE)
file = args[1]
#file="http://download.txgen.tamu.edu/shichen/shuyu/TXE_b2/evaluate_imputation/accuracy_summary.txt"
data = read.table(file, header=T, sep="\t")

library(ggplot2)

p = ggplot(data, aes(Allele_freq, Accuracy))
p = p + geom_bar(stat="identity", position="dodge", aes(fill=as.factor(GP_cutoff))) + theme_light() +  
  theme(plot.background = element_rect(fill = "white")) +
  guides(fill = guide_legend(title = "GP cutoff")) + 
  theme(axis.text.x = element_text(angle = 45, hjust=1), axis.text=element_text(size=12),axis.title=element_text(size=14,face="bold"))

pdfout = paste(file, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")
                                                                                                                                                                                                                                                                                                                                               ./plot_imputation_accuracy_sum_table.R                                                              0000664 �   ���   ���00000003361 13451166740 024012  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           args = commandArgs(trailingOnly=TRUE)
file = args[1]
#file="http://download.txgen.tamu.edu/shichen/Thomson/18334Tho/imputation/imp_eval/imputation_eval.2.tsv.sum.table.csv"
library(ggplot2)

data = read.table(file, header=F, sep=",", stringsAsFactors =F)

names = as.character( unlist(list(data[1, ])[[1]]) )

data = data[-1, ]

data = as.data.frame(sapply(data, as.numeric) )

for (i in 1:nrow(data)){
  data[i, 2:11]  = data[i, 2:11] / data[i, 12]
}

gp = numeric(100)
type = character(100)
acc =  numeric(100)

index = 0
for (i in 1:10) {
  for (j in 2:11){
    index = index + 1
    gp[index] = data$V1[i]
    type[index] = names[j]
    acc[index] = data[i, j]
  }
}

df = data.frame(GP=gp, Type=type, Proportion=acc)

p = ggplot(df, aes(Type, Proportion))
p = p + geom_bar(stat="identity", position="dodge", aes(fill=as.factor(GP))) + theme_light() +
  theme(plot.background = element_rect(fill = "white")) +
  guides(fill = guide_legend(title = "GP cutoff")) +
  theme(axis.text.x = element_text(angle = 45, hjust=1), axis.text=element_text(size=12),axis.title=element_text(size=14,face="bold"))

pdfout = paste(file, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")

pdfout = paste(file, "accuracy_sum_up", "pdf", sep=".")

colnames(data) = names
data$Accuracy = round(data$Accuracy, 2)
p = ggplot(data = data, aes(GP, Accuracy)) + 
  geom_bar(stat="identity", fill="salmon") + ggtitle("Imputation accuracy") +
  geom_text(aes(label=Accuracy), vjust=-0.3, size=3.5)+
  coord_cartesian(ylim=c(0.80, 1)) +
  scale_x_continuous("Genotype probability cutoff", breaks = data$GP ) + 
  theme(axis.text=element_text(size=18),axis.title=element_text(size=20,face="bold"), plot.title = element_text(size=25, face="bold", hjust = 0.5))

ggsave(pdfout, plot=p, device="pdf")

                                                                                                                                                                                                                                                                               ./process_v2.pl                                                                                     0000775 �   ���   ���00000031501 13451157275 017160  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
use File::Basename;
use File::Copy;
use Getopt::Long;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;

my $sUsage = qq(
perl $0
-acc       Accession name
-reads     provide pairend reads (separate with comma) and/or single-end reads:  R1.fq,R2.fq  and/or single.fq
-ref       reference in fasta format
-refindex  bowtie2 index basename
-outdir    The directory for output
-MAQ       mapping quality cutoff, default is 0
-CPU       number of CPUs that will be used to run bowtie2
-bowtie2   The path to executable bowtie2: ie, /home/DNA/Tools/bowtie2/bin/bowtie2
);

##
# predefined 
my $bamutil = "/home/wangsc/Tools/bamUtil/bin/bam ";
check_exec($bamutil);
my $samtools_bin = `which samtools`;
chomp $samtools_bin;
check_exec($samtools_bin);
my $picard_dir  = "/software/easybuild/software/picard/1.119-Java-1.7.0_80/";
#my $GATK_jar = "/home/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $GATK_jar = "/home/wangsc/Tools/GATK_3.5/GenomeAnalysisTK.jar ";

my (@read_files, $ref_fasta, $ref_index, $accession_name, $RG);
my ( $outdir, $MAX_THREADS) = ("./", 1); # default values
my $bowtie2_exec = "/homes/wangsc/Tools/bowtie2/bowtie2";
my $maq_cutoff = 0;

##

GetOptions('reads=s{1,}' => \@read_files,
					 'ref=s'       => \$ref_fasta,
					 'refindex=s'  => \$ref_index,
					 'bowtie2=s'   => \$bowtie2_exec,
					 'outdir=s'    => \$outdir,
					 'acc=s'       => \$accession_name,
					 'RG=s'       => \$RG,
					 'CPU=i'      => \$MAX_THREADS,
					 'MAQ=i'	=>\$maq_cutoff
					 );
die $sUsage unless (defined $ref_fasta and defined $ref_index);
die $sUsage unless @read_files > 0;

$RG = $accession_name unless $RG;

mkdir($outdir) if $outdir=~/\S/;

my @pair_reads = ([], []); 
my @single_reads;
map{
	chomp;
	my @p = split /,/, $_;
	if(@p == 2){
		push @{$pair_reads[0]}, $p[0];
		push @{$pair_reads[1]}, $p[1];
	}
	else{
		push @single_reads, $p[0]
	}
} @read_files;

## check steps that have been finished
my $latest_step = -2;
my $process_log = $outdir . "/$accession_name" . "_proc.log";
my $PROC; ## filehandle
if(-e $process_log){
  $latest_step = &get_latest_step($process_log);
  open($PROC, ">>$process_log") or die "can not open the file $process_log !\n"; 
}
else{
  open($PROC, ">$process_log") or die "can not open the file $process_log !\n";
}


## check sam
my $sam_file = $outdir . "/" .$accession_name . ".sam";
print STDERR "Previsous step finished: ", $latest_step, "\n";
if($latest_step > -2 ){
  print_time_stamp("Checking the sam file $sam_file is done!");
}
else{
  print_time_stamp("Checking the sam file $sam_file");
  if (simple_check($sam_file) eq "FAIL"){die "$accession_name alignment DID NOT FINISH Because the sam file $sam_file seems not complete!\n"}
  print_time_stamp("Checking the sam file $sam_file is done!");
  print $PROC "-1\n";  #output to the processing log file
}
## Files to be generated
my $bam_file = $sam_file; $bam_file =~ s/sam/bam/;
my $sorted_bam = dirname($bam_file) . "/". basename($bam_file, ".bam") . "_sorted.bam";
my $bam_addRG = dirname($sorted_bam) . "/" . basename($sorted_bam, ".bam") . "_addRG.bam";
my $rmdup_bam = dirname($bam_addRG) . "/" . basename($bam_addRG, ".bam") . "_rmDup.bam";
my $realigned_bam = dirname($rmdup_bam) . "/" . basename($rmdup_bam, ".bam") . "_realigned.bam";
my $qc_bam = dirname($realigned_bam) . "/" . basename($realigned_bam, ".bam") . "_QC.bam";

my @proc_files = ($sam_file, $bam_file, $sorted_bam, $bam_addRG, $rmdup_bam, $realigned_bam, $qc_bam);

## subroutines need to generate these files
# 1. samtobam; 2. sortbam; 3. addRg; 4. rmdup; 5.realign; 6. qc
my @subroutines = (
{"name" => "samTobam", "func" => \&samTobam},
{"name" => "SortBam", "func" => \&sort_bam_files },
{"name" => "addRG", "func" => \&addRG},
{"name" => "RemovingDuplicates", "func" => \&picard_duplicate_marking},
{"name" => "ReAlignment", "func" => \&GATK_realignment },
{"name" => "MappingQualityFiltering", "func" => \&quality_filter}
);

## start
my $step = 0;
my %step_failed = ();
while ($step <= $#subroutines){
	print_time_stamp("Running " . $subroutines[$step]->{"name"} .", step " . ($step+1) ." of " . (scalar @subroutines));
        unless($step > $latest_step){print_time_stamp($subroutines[$step]->{"name"} . " is done!"); $step++; next}
	my $input = $proc_files[$step];
	&index_bam_files($input) if $input =~ /bam$/;
	my $output = $proc_files[$step+1];
	#unless (simple_check($output) eq "FAIL"){print $PROC $step, "\n"; next}
	my $func = $subroutines[$step]->{"func"};
	$func->($input);
	sleep(60); # sleep 60 seconds
	if(rerun_if_need($output, $input, $func)){
	  $step_failed{$step} = 0 unless exists $step_failed{$step};
	  $step_failed{$step}++;
	  if($step_failed{$step} > 1){die "Step " . $subroutines[$step]->{"name"} . " failed more then once !\n"}
	  $latest_step--;
	  $step--;
	  if($step < 0){die "Sam to Bam failed!! Please check the SAM file: $sam_file !\n"}
	  next;
	}
	else{
	  print_time_stamp("Step " . $subroutines[$step]->{"name"} . " is done!");
	  # remove the input file to save space
	  unlink($input) if $step < 4;  # keep the realinged 
          print $PROC $step, "\n";  # output to the processing log file.
	  $step++;
	}
}
&get_stat($bam_file);  # get the alignment stats
simple_check($qc_bam); # check the final bam file;
&index_bam_files($qc_bam);
## finished
print_time_stamp("Finished all processing steps for accession $accession_name");
close $PROC;


## Subroutines
sub clean_sorted_bam {
  my $bam = shift;
  print_time_stamp("\tStart cleaning the bam file $bam!");
  my $tmp="/tmp/" . basename($bam) . ".tmp" . time();
  open(my $IN, "$samtools_bin view -h $bam |") or die $!;
  open(my $OUT, "|$samtools_bin view -Sb - >$tmp") or die $!;
  my %pre=();
  while(<$IN>){
    next if /null/i;
    if(/^\@/){print $OUT $_; next}
    my @t = split /\s+/, $_;
    my $id = join(" ", @t[0,1]);
    next if exists $pre{$id};
    $pre{$id}=1;
    print $OUT $_;
  }
  close $IN;
  close $OUT;
  die "Cleaning $bam failed!\n" unless move($tmp, $bam);  
  print_time_stamp("\tFinished cleaning the bam file $bam!");
}


sub get_latest_step {
  my $file = shift;
  my $line = -2;
  if(-e $file){
    open(my $IN, $file) or die $!;
    while(<$IN>){
      chomp;
      $line = $1 if /^(\S+)$/;
    }
    close $IN;
  }
  return $line;
}

sub rerun_if_need {
  my $bam = shift;
  my $f_for_func = shift;
  my $func = shift;
  my $retry = 0;
  while(simple_check($bam) eq "FAIL"){
    $retry++;
    return 1 if $retry > 1;
    print_time_stamp("\tRetrying to generate $bam");
    $func->($f_for_func);
  }
  return 0;
}

sub simple_check
{
  my $file = shift;
  my $flag = 0;
  $flag = 1 if -e $file and validate_sam($file);
  return $flag?"PASS":"FAIL";
}


sub quality_filter
{
  my $file = shift;
  my $maq = $maq_cutoff;
  print_time_stamp("\tStart removing low mapping Quality reads in bam file $file ......");
  my $out = dirname($file) . "/" . basename($file, ".bam") . "_QC.bam";
  open(IN, "$samtools_bin view -h -q $maq $file |") or die "Couldn't open file $file\n";
  open(OUT, "|$samtools_bin view -Sb - >$out") or die "Couldn't open file $out\n";
  while(<IN>){
    print OUT $_;
  }
  close IN;
  close OUT;
  system("$samtools_bin index $out")
}

sub rm_overfloat
{
  my $file = shift;
  my $rm_file = dirname($file) . "/" . basename($file, ".bam") . "_rm.bam";
  my $MAX = 2**29 - 1;
  open(IN , "$samtools_bin view -h $file |") or die;
  open(OUT, "|$samtools_bin view -Sb - >$rm_file") or die;
  while(<IN>){
    if(/^\@/){print OUT $_; next}
    my @t = split /\s+/, $_;
    print OUT if $t[3] < $MAX and $t[7] < $MAX and $t[8] < $MAX;
  }

  close IN;
  close OUT;
  return $rm_file;
}


sub run_bowtie2
{
	# run_bowtie2($bowtie2_exec, $outdir, $accession_name, \@pair_reads, \@single_reads);
	my ($bowtie2, $refindex, $out, $acc, $pair_ref, $single_ref) = @_;
	print_time_stamp("Start runing bowtie2 alignemtn for acc $acc");
	my $cmd = "$bowtie2 -x $refindex ";
	if(@{$pair_ref->[0]} > 0){
		$cmd .=  " -1 ". join(",", @{$pair_ref->[0]}) . " -2 ". join(",", @{$pair_ref->[1]});
	}
	
	if (@{$single_ref} > 0){
		$cmd .= " -U ".join(",", @$single_ref);
	}
	
	my $sam = $outdir . "/" .$acc . ".sam";
	my $log = $outdir . "/". $acc . "_align.log";
	
	$cmd .= "--rg-id $acc --very-sensitive-local -p $MAX_THREADS -S $sam 2>$log";

	
	print_time_stamp("\t$cmd");
	die if system($cmd);
	return $sam;
}


sub samTobam
{
	my $file = shift or die $!;
	my $bam = $file;
	$bam=~s/sam$/bam/;
	print_time_stamp("Convert SAM to BAM");
	my $cmd = "$samtools_bin  view -Shb -F 4 $file  >$bam";
	print STDERR  "$cmd failed !\n" if system($cmd);
	return $bam;
 }

sub picard_duplicate_marking
{
	my @bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $bam = $_;
		print_time_stamp("\tStart checking (not removed for GBS) duplicates in bam file $bam ......");
		## &clean_sorted_bam($bam);
		my $merics_file = $bam . ".metrics";
		my $out = dirname($bam) . "/" . basename($bam, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx15G -Djava.io.tmpdir=./  -jar $picard_dir/MarkDuplicates.jar I=$bam O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
		print "$cmd failed \n" if system($cmd);
	}@bams;
}

sub validate_sam 
{
  # return o for notValidated; 1 for validated
  my $file = shift;
  my $out = $file . "_validation_output.txt";
  ##my $cmd = "java -Xmx15G -jar $picard_dir/ValidateSamFile.jar I=$_ O=$out IGNORE_WARNINGS=true VALIDATE_INDEX=false $additional";
  #my $cmd = "$samtools_bin view $file >/dev/null 2>$out";
  my $cmd = $bamutil . " validate --in $file --verbose 2>$out";
  if(system($cmd)){return 0}
  return 1;
}

sub GATK_realignment
{
	my @sorted_bams = @_;
	index_bam_files(@sorted_bams);
	my @generate_interval_cmds;
	my @intervals;
	map {
		print_time_stamp("\tStart realignment step 1 of bam file $_ ......");
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx15G -jar $GATK_jar -K /home/wangsc/gsamembers_broadinstitute.org.key -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		print  "$cmd failed\n" if system($cmd);
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
		
	my @realigned_bams;
	my @realign_cmds;
	map{
		print_time_stamp("\tStart realignment step 2 of bam file $_ ......");
		my $interval = $_ . ".intervals";
		my $realn_bam = dirname($_) . "/" . basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx15G -jar $GATK_jar -K /home/wangsc/gsamembers_broadinstitute.org.key -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		print  "$cmd failed\n" if system($cmd);
		push @realign_cmds, $cmd;
	} @sorted_bams;

}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . " index " . $_}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		print_time_stamp("\tStart sorting bam file $bam ......");
		my $sorted_prefix = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . " sort -m 20G  $bam -o ${sorted_prefix}.bam";
		push @sort_cmds, $cmd #unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub sort_bam_files_picard
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_bam = dirname($bam) . "/" . basename($bam, ".bam") . "_sorted.bam";
		push @return , $sorted_bam;
		my $cmd = "java -jar $picard_dir/SortSam.jar I=$bam O=$sorted_bam SO=coordinate";
		push @sort_cmds, $cmd;
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub addRG
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		print_time_stamp("add RG to bam file $bam");
		my $id = basename($bam, ".bam");
		my $out = dirname($bam). "/" . $id . "_addRG.bam";
		# my $rg = $id;
		# $rg =~ s/Sample_\S+_ExomeCapture/ExomeCapture/;
		push @return, $out;
		my $cmd = "java -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$RG LB=SeqCap ID=$RG VALIDATION_STRINGENCY=SILENT";
		push @cmds, $cmd;
	}
	run_parallel_jobs(\@cmds, $MAX_THREADS);
	return @return;
}


sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		print_time_stamp("\nRunning command: $cmd\n");
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}


sub print_time_stamp
{
        my $comments = shift;
        my $time = localtime();
        print STDERR $time, "\t", $comments, "\n";
}

sub help
{
	print $sUsage;
	exit;
}
	


sub get_stat {

  my @bams = @_;
  foreach my $f( @bams){
    my $stat = $f. ".aln.stat.txt";
    my $cmd = "$samtools_bin flagstat $f >$stat";
    die "$cmd failed!\n" if system($cmd);
  }

}

sub check_exec {
  my $exec = shift;
  $exec =~ s/\s//g;
  unless (-e $exec and -x $exec){
    die "$exec is not exists or not executable!\n";
  }
}
                                                                                                                                                                                               ./run_ref_panel.sh                                                                                  0000664 �   ���   ���00000003321 13461662764 017712  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           ## perform imputation repeatedly to evalue the accuracy
module load parallel

ORIG_VCF=$1
REF_PANEL=$2
PROBABILITY=$3
cycles=1

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
  
                                                                                                                                                                                                                                                                                                               ./submit_sequential_jobs.pl                                                                         0000775 �   ���   ���00000000740 13451157275 021646  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
my @arr; 
while(<>){
  next if /^\#/ or /^\s+$/;
  chomp;
  push @arr, $_;
}

my $job="";
foreach my $ind (0..$#arr){
  if ($ind == 0){
    my $cmd = "bsub < $arr[$ind]";
    print $cmd, "\n";
    my $r = `$cmd`;
    $job = $1 if $r =~ /<(\d+)>/;
  }
  else{
    unless ($job){ print "Failed running $arr[$ind-1] !!";  exit }
    my $cmd = "bsub -w \"done($job)\" < $arr[$ind]";
    print $cmd, "\n";
    my $r = `$cmd`;
    $job = $1 if $r =~ /<(\d+)>/;
  }
}
                                ./unifiedgenotyper.pl                                                                               0000775 �   ���   ���00000025725 13451157275 020466  0                                                                                                    ustar   shichen.wang                    shichen.wang                                                                                                                                                                                                           #!/usr/bin/perl -w
use strict;
#use lib '/homes/wangsc/perl_lib'; # for beocat;
use lib '/home/wangsc/perl5/lib/perl5';
use Parallel::ForkManager;
use File::Basename;
use Getopt::Long;

my $sUsage = qq(
###########################################################################################################################
	Suppose we have bam files for each accessions separately (sample1.bam, sample2.bam, ...), 
	call variations using GATK based on these bam files.
	Steps:
	1. sort each bam file (samtools sort) + index the bam file (samtools index)
	2. realignment (GATK, -T RealignerTargetCreator + -T IndelRealigner)
	3. MarkDuplicates for realign bam file (picard, MarkDuplicates.jar) + index the bam file (samtools index)
	4. Base quality recalibration (GATK, -T CountCovariates) + index for recalibrated bam file (samtools index)
	5. Calling variations (GATK, -T UnifiedGenotyper)
	
	Usage:	
	perl $0
	-ref                reference fasta file
	-out_prefix         output prefix for variation file
	-region             specific region for variation calling, chr_1:12345-876812
	-dcov               mean coverage, default: 200
	-bam                processed bam files: 1.bam 2.bam 3.bam
        -params		    Other parameters for GATK, such as "--output_mode EMIT_ALL_SITES"
	-help               print this message
	
	example:
	perl $0 -ref ref.fasta  -out_prefix test -region 1AL:1-9607790  -bam sample*.bam
	
	SW\@KSU Dec.01.2012
###########################################################################################################################

);

die $sUsage unless @ARGV;

# predefined 
#my $samtools_bin = "/homes/bioinfo/bioinfo_software/samtools/samtools ";
my $bamutil = "/home/wangsc/Tools/bamUtil/bin/bam ";
#check_exec($bamutil);
my $samtools_bin = `module load SAMtools/0.1.19-intel-2015B; which samtools`;
chomp $samtools_bin;
#check_exec($samtools_bin);
my $picard_dir  = "/software/easybuild/software/picard/1.56-Java-1.7.0_80/";
##my $GATK_jar = "/home/wangsc/Tools/GenomeAnalysisTK-2.2-8-gec077cd/GenomeAnalysisTK.jar ";
my $GATK_jar = "/home/wangsc//Tools/GATK_3.5/GenomeAnalysisTK.jar ";
my ($ref_fasta, $out_prefix, $region, $MAX_THREADS, @bam_files, $help, $dcov, $gatk_params);
$MAX_THREADS = 1;
my $TMP;
GetOptions(
'ref=s'        =>	\$ref_fasta,
'nt=i'         =>	\$MAX_THREADS,
'region=s'     =>	\$region,
'out_prefix=s' => \$out_prefix,
'tmp=s'        => \$TMP,
'dcov=i'        => \$dcov,
'bam=s{1,}'    =>	\@bam_files,
'params=s' => \$gatk_params,
'help'         =>	sub{help()}
);


die $sUsage unless (defined $ref_fasta and defined $out_prefix and (@bam_files >=1) );

$dcov = 200 unless $dcov;

#print join("\n", ($ref_fasta, $out_prefix, $MAX_THREADS, @bam_files)), "\n"; exit;

print_time_stamp("Start GATK pipeline .....");
## index ref fasta
unless (-e $ref_fasta.".fai"){
	print_time_stamp("\tIndexing reference fasta file " . $ref_fasta);
	die "Index reference fasta failed \n" if system($samtools_bin . " faidx $ref_fasta");
	print_time_stamp("\tFinish indexing reference fasta file");
}
#
#print join("\t", @bam_files), "\n";
#
## add RG to bam file
#print_time_stamp("\tAdd RG to bam files ......");
#my @bams_addRG = map {basename($_, ".bam") . "_addRG.bam";} @bam_files;
#print join("\t", @bams_addRG), "\n";
##addRG(@bam_files);
#print_time_stamp("\tFinished ......");	
#
## sort bam files
#print_time_stamp("\tStart sorting bam files ......");
#my @sorted_bams = map {basename($_, ".bam") . "_sorted.bam";} @bams_addRG;
#print join("\t", @sorted_bams), "\n";
##sort_bam_files(@bams_addRG);
#print_time_stamp("\tFinish sorting bam files ......");	
#
## reassign mapping quality
#print_time_stamp("\tStarted reassigning mapping quality ......");
#my @bams_MQ= map {basename($_, ".bam") . "_MQ.bam"} @sorted_bams;
#print join("\t", @bams_MQ), "\n";
##reassign_mapping_quality_parallel($MAX_THREADS, @sorted_bams);
#print_time_stamp("\tFinished reassigning mapping quality ......");
#
## index bam files
#print_time_stamp("\tStart indexing bam files ......");
##index_bam_files(@sorted_bams);
#print_time_stamp("\tFinish indexing bam files ......");
#
## realignment, two steps
#print_time_stamp("\tStart realignment of bam files ......");
#my @realigned_bams = map {basename($_, ".bam") . "_realigned.bam";} @sorted_bams;
#print join("\t", @realigned_bams), "\n";
##GATK_realignment(@sorted_bams);
#print_time_stamp("\tFinish realignment of bam files ......");
#
## duplicate marking
#print_time_stamp("\tStart removing duplicates in bam files ......");
#my @rmdup_bams = map {basename($_, ".bam") . "_rmDup.bam";} @realigned_bams;
#print join("\t", @rmdup_bams), "\n";
##picard_duplicate_marking(@realigned_bams);
#print_time_stamp("\tFinish removing duplicates in bam files ......");
#
## reindex
#print_time_stamp("\tStart reindexing bam files ......");
##index_bam_files(@rmdup_bams);
#print_time_stamp("\tFinish reindexing bam files ......");


# SNP and Indel calling
print_time_stamp("\tStart calling variations from bam files ......");
my $raw_variation_vcf = variation_calling_unifiedgenotyper($gatk_params, @bam_files);
print_time_stamp("\tFinish calling variations from bam files ......");

# Variant Quality Score Recalibration, VQSR (not implmented yet)
#print_time_stamp("\tStart Variant Quality Score Recalibration ......");
#VQSR($raw_variation_vcf);
#print_time_stamp("\tFinish Variant Quality Score Recalibration ......");


# Done
#print_time_stamp("Finish GATK pipeline except VQSR.....");

# Subroutines
sub VQSR 
{

}


sub variation_calling
{
	my @recal_bams = @_;
	my @params = map{"-I ".$_} @recal_bams;
	my $out = $out_prefix . "_raw.snps.indels.vcf";
	my $cmd = "java -jar $GATK_jar -T HaplotypeCaller -R $ref_fasta -nt 20 ". join(" ", @params) . " -o $out";
  	die "!!! $cmd failed\n" if system($cmd);
  
  	return $out;
}

sub variation_calling_unifiedgenotyper
{
	my $gatk_params = shift;
        my @recal_bams = @_;
        my @params = map{"-I ".$_} @recal_bams;
        my $out = $out_prefix . "_raw.snps.indels.vcf";
        #my $cmd = "java -Xmx10G -Djava.io.tmpdir=/homes/wangsc/tmp  -jar $GATK_jar -T UnifiedGenotyper -R $ref_fasta ". join(" ", @params) . " --genotype_likelihoods_model BOTH " . (defined $region?"-L $region ":" ") . "-dcov 200 -o $out";
        my $cmd = "java -Xmx30G  -jar $GATK_jar -T UnifiedGenotyper -R $ref_fasta ". join(" ", @params) . " --genotype_likelihoods_model BOTH " . (defined $region?"-L $region ":" ") . "-dcov $dcov -o $out" . " -drf BadMate -drf DuplicateRead -U ALLOW_N_CIGAR_READS";
        $cmd  = $cmd . " " .  $gatk_params if $gatk_params;

  	die "!!! $cmd failed\n" if system($cmd);

	return $out;
}


sub base_recalibration
{
	my @rmdup_bams = @_;
	my @recal_bams;
	
	map{
		my $grp = basename($_, ".bam") . ".grp";
		
		# Step 1. Generates recalibration table, -T BaseRecalibrator
		my $cmd_a = "java -Xmx3g -jar $GATK_jar -T BaseRecalibrator -I $_  -R $ref_fasta -o $grp";
	  
	  print_time_stamp("\nRunning command: $cmd_a\n");
	  die "!!!\t$cmd_a failed\n" if system($cmd_a);
	  
	  # Step 2. print reads,  -T PrintReads
	  my $out_bam = basename($_, ".bam") . "_recal.bam";
	  my $cmd_b = "java -jar $GATK_jar -T PrintReads -R $ref_fasta -nt $MAX_THREADS -I $_  -BQSR $grp -o $out_bam";
   
   print_time_stamp("\nRunning command: $cmd_b\n");
   die "!!!\t$cmd_a failed\n" if system($cmd_b);
   
   push @recal_bams, $out_bam;
	  
	}@rmdup_bams;
	
	return @recal_bams;
}


sub picard_duplicate_marking
{
	my @realn_bams = @_;
	my @picard_cmds;
	my @rmdup_bams;
	map{
		my $merics_file = $_ . ".metrics";
		my $out = basename($_, ".bam") . "_rmDup.bam";
		push @rmdup_bams, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/MarkDuplicates.jar I=$_ O=$out M=$merics_file REMOVE_DUPLICATES=true AS=true";
		push @picard_cmds, $cmd;
	}@realn_bams;
	
	run_parallel_jobs(\@picard_cmds, $MAX_THREADS);
	
	return @rmdup_bams;
}


sub GATK_realignment
{
	my @sorted_bams = @_;
	my @generate_interval_cmds;
	my @intervals;
	map {
		my $interval = $_ . ".intervals";
		push @intervals, $interval;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T RealignerTargetCreator -o $interval";
		push @generate_interval_cmds, $cmd;
	}@sorted_bams;
	
	run_parallel_jobs(\@generate_interval_cmds, $MAX_THREADS);
	
	my @realigned_bams;
	my @realign_cmds;
	map{
		my $interval = $_ . ".intervals";
		my $realn_bam = basename($_, ".bam") . "_realigned.bam";
		push @realigned_bams, $realn_bam;
		my $cmd = "java -Xmx3G -jar $GATK_jar -I $_ -R $ref_fasta -T IndelRealigner -targetIntervals $interval -o $realn_bam";
		push @realign_cmds, $cmd;
	} @sorted_bams;

	run_parallel_jobs(\@realign_cmds, $MAX_THREADS);
	return @realigned_bams;
}

sub index_bam_files
{
	my @bam_files = @_;
	my @index_cmds = map{$samtools_bin . " index " . $_;}@bam_files;
	run_parallel_jobs(\@index_cmds, $MAX_THREADS);
	
}

sub reassign_mapping_quality
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $default_mapping_quality = 100;
	foreach my $bam (@bam_files)
	{
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
	}
		
}

sub reassign_mapping_quality_parallel
{
	my $max = shift;
	my @bam_files = @_;
	my @return;
	my @cmds;
	my $pm = new Parallel::ForkManager($max);
	foreach my $bam (@bam_files)
	{
		$pm->start and next;
		my $out = basename($bam, ".bam") . "_MQ.bam";
		open (OUT, "|$samtools_bin view -bS - > $out") or die "";
		open (IN, "$samtools_bin view -h $bam|") or die "can't pipe file $bam\n";
		while(<IN>)
		{
			 if(/^\@/){print OUT $_; next}
			chomp;
			my @data = split /\s+/, $_; 
			$data[4] = 100;
			print OUT join("\t", @data), "\n";
		}
		close IN;
		close OUT;
		
		$pm->finish;
	}
	
	$pm->wait_all_children;	
}


sub sort_bam_files
{
	my @bam_files = @_;
	my @return;
	my @sort_cmds;
	foreach my $bam (@bam_files)
	{
		my $sorted_prefix = basename($bam, ".bam") . "_sorted";
		push @return , $sorted_prefix . ".bam";
		my $cmd = $samtools_bin . "sort -m 3000000000 $bam $sorted_prefix";
		push @sort_cmds, $cmd unless -e ($sorted_prefix . ".bam");
	}
	
	run_parallel_jobs(\@sort_cmds, $MAX_THREADS);
	
	return @return;

}

sub addRG
{
	my @bam_files = @_;
	my @return;
	my @cmds;
	
	foreach my $bam (@bam_files)
	{
		my $id = basename($bam, ".bam");
		my $out = $id . "_addRG.bam";
		push @return, $out;
		my $cmd = "java -Xmx3G -jar $picard_dir/AddOrReplaceReadGroups.jar I=$bam O=$out PL=illumina PU=barcode SM=$id LB=SeqCap ID=$id";
		push @cmds, $cmd;
	}
	run_parallel_jobs(\@cmds, $MAX_THREADS);
	return @return;
}

sub run_parallel_jobs
{
	my ($cmdref, $max) = @_;
	my $pm = new Parallel::ForkManager($max);
	foreach my $cmd (@$cmdref)
	{
		$pm->start and next;
		print_time_stamp("\nRunning command: $cmd\n");
		system($cmd);
		$pm->finish;
	}
	$pm->wait_all_children;
}


sub print_time_stamp
{
        my $comments = shift;
        my $time = localtime();
        print STDERR $time, "\t", $comments, "\n";
}

sub help
{
	print $sUsage;
	exit;
}

			
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           