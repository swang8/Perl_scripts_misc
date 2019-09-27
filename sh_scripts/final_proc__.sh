MAX_MISS=$1
MIN_MAF=$2

output=all_raw_genotyped_MaxMissing${MAX_MISS}_MAF${MIN_MAF}.vcf

#perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){next if /\#/; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless ($ref+$alt) >= ($tot * (1-$mm)); $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISS $MIN_MAF Variations/*.vcf >$output
perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){next if /\#/; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISS $MIN_MAF Variations/*.vcf >$output

perl -ne 'if(/#CHROM/){s/_sorted//g; print $_; exit}' Variations/*.vcf >vcf.header

perl ~/pl_scripts/find_pos.pl  /home/wangsc/tiered_storage/Projects/GBS/wheat/ref_data/wheat_concate/0.Contigs_coordinates_in_concatenated_3B-splited.txt $output  > ${output}_trueContig

perl -ne 'BEGIN{$r=`wc -l $ARGV[0]`; $r+=0} $n++; if($n<=$r){chomp; @t=split /\s+/,$_;$h{join(":", @t[0,1])} = [@t[2,3]]}else{next if /\#/; chomp;  @t=split /\s+/,$_; $id=join(":", @t[0,1]); die $! if not exists $h{$id}; @t[0,1] = @{$h{$id}}; $t[2] = join(":", @{$h{$id}}); print  join("\t", @t), "\n"  }'  ${output}_trueContig  ${output}   >${output}_trueContig.vcf

perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ unless length $t[3] > 1 or length $t[4] > 1' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_SNPsOnly.vcf
perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ if length $t[3] > 1 or length $t[4] > 1' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_IndelsOnly.vcf
perl -ne 'if(/\#CHROM/){print $_; next} @t=split /\s+/, $_ ; next if $t[3]=~/,/ or $t[4] =~ /,/ ;print $_ ' vcf.header ${output}_trueContig.vcf  > ${output}_trueContig_rmMultiAllele.vcf

perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_SNPsOnly.vcf >${output}_trueContig_SNPsOnly.hmp.tsv
perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_IndelsOnly.vcf >${output}_trueContig_IndelsOnly.hmp.tsv
perl ~/pl_scripts/vcf_to_hmp_v2.pl ${output}_trueContig_rmMultiAllele.vcf >${output}_trueContig_rmMultiAllele.hmp.tsv

perl -ne 'next if /^\#/;  @t=split /\s+/,$_; next if $t[3]=~/,/ or $t[4]=~/,/;  $type="SNP"; $type="Indel"  if length $t[3] > 1 or length $t[4] > 1;  $chr=$1 if $t[0]=~/\d+_(\S+)/; $chr=~s/_v2//; $h{$chr}{$type}++; END{@arr= sort{$a cmp $b}keys %h; print join(" ", qw(Chr SNP Indel)), "\n";  foreach $chr(@arr){@p=(); map{push @p, exists $h{$chr}{$_}?$h{$chr}{$_}:0}("SNP", "Indel"); print join(" ", $chr, @p), "\n"} }'  ${output}_trueContig_rmMultiAllele.vcf  >${output}_trueContig_rmMultiAllele.vcf.count
