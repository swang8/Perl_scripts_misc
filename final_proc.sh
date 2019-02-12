MAX_MISS=$1
MIN_MAF=$2

output=all_raw_genotyped_MaxMissing${MAX_MISS}_MAF${MIN_MAF}.vcf

## Filter variations with missing and MAF
#perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){next if /\#/; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless ($ref+$alt) >= ($tot * (1-$mm)); $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISS $MIN_MAF Variations/*.vcf >$output
perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){next if /\#/; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISS $MIN_MAF Variations/*.vcf >$output

## get the header
perl -ne 'if(/#CHROM/){s/_sorted//g; print $_; exit}' Variations/*.vcf >vcf.header

## replace the artificial contigs with true contigs
BED="/home/wangsc/scratch_fast/reference/wheat_ref/Wheat_IWGSC_WGA_v1.0_pseudomolecules/161010_Chinese_Spring_v1.0_pseudomolecules_parts_to_chr.bed_1base"
perl ~/pl_scripts/find_pos_v2.pl $BED $output >${output}_trueContig.vcf

perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ unless length $t[3] > 1 or length $t[4] > 1' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_SNPsOnly.vcf
perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ if length $t[3] > 1 or length $t[4] > 1' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_IndelsOnly.vcf

## remove multiple allelic variations
perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ ' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_rmMultiAllele.vcf

# transform vcf into hmp
perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_SNPsOnly.vcf >${output}_trueContig_SNPsOnly.hmp.tsv
perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_IndelsOnly.vcf >${output}_trueContig_IndelsOnly.hmp.tsv
perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_rmMultiAllele.vcf >${output}_trueContig_rmMultiAllele.hmp.tsv

# count variations for each chromosome
perl -ne 'next if /^\#/;  @t=split /\s+/,$_; next if $t[3]=~/,/ or $t[4]=~/,/;  $type="SNP"; $type="Indel"  if length $t[3] > 1 or length $t[4] > 1;  $chr=$1 if $t[0]=~/\d+_(\S+)/; $chr=~s/_v2//; $h{$chr}{$type}++; END{@arr= sort{$a cmp $b}keys %h; print join(" ", qw(Chr SNP Indel)), "\n";  foreach $chr(@arr){@p=(); map{push @p, exists $h{$chr}{$_}?$h{$chr}{$_}:0}("SNP", "Indel"); print join(" ", $chr, @p), "\n"} }'  ${output}_trueContig_rmMultiAllele.vcf  >${output}_trueContig_rmMultiAllele.vcf.count

# calculage MAF and missing
perl -ne '$n++; chomp; @t=split /\s+/,$_; if($n==1){@arr=@t; next} map{$h{$arr[$_]}++ if $t[$_]=~/\.\/\./}9..$#t; END{ print join("\t", qw(Accession Missed_SNPs Total Proportion)), "\n";  map{print $_,"\t", $h{$_}, "\t", $n-1, "\t", $h{$_}/($n-1), "\n"}sort{$h{$b} <=> $h{$a}}keys %h}'  ${output}_trueContig_rmMultiAllele.vcf >${output}_trueContig_rmMultiAllele.vcf_accession_missing.count.txt

perl -ne 'BEGIN{print join("\t", qw(Contig Pos Missing MAF)), "\n"}next if /\#/; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print join("\t", @t[0,1], $miss/$tot, $maf), "\n"' ${output}_trueContig_rmMultiAllele.vcf  >${output}_trueContig_rmMultiAllele.missing.maf.txt

## plot
/software/easybuild/software/R/3.2.5-intel-2015B-default-mt/bin/Rscript plot.R  ${output}_trueContig_rmMultiAllele.missing.maf.txt 
