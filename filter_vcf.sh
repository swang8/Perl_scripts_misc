MAX_MISSING=$1
MIN_MAF=$2
VCF=$3

perl -e '$mm = shift; $min_maf=shift; @fs=@ARGV; foreach $f(@fs){open(IN, $f) or die $!; while(<IN>){if(/\#/){if(/\#CHROM/){print $_ unless $header; $header=1}; next}; $miss=()=/\.\/\./g; @t=split /\s+/,$_; $tot = scalar @t - 9; $ref=()=/0\/0/g; $alt=()=/1\/1/g;   next unless $miss <= ($tot * $mm); next unless $ref+$alt > 0;  $maf=$ref/($ref+$alt); $maf=1-$maf if  $maf > 0.5; print $_ if $maf >= $min_maf } close IN; } '  $MAX_MISSING $MIN_MAF $VCF >${VCF}_MaxMissing${MAX_MISSING}_MinMAF${MIN_MAF}
