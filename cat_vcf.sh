# perl -ne 'if(/\#CHR/){print $_ unless $header; $header=1} next if /\#/; print $_' $@

perl -e '@fs=@ARGV; foreach $f(@fs){if($f=~/gz$/){open(IN, "zcat $f |") or open(IN, $f)} while(<IN>){if(/\#CHR/){print $_ unless $header; $header=1} next if /\#/; print $_}}' $@
