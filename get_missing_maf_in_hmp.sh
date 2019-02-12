# vcf
#perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; @t=split /\s+/,$_; $ref=$alt=$missing=$het=0; map{$ref++ if /0\/0/; $alt++ if /1\/1/; $het++ if /0\/1/;  $missing++ if /\.\/\./}@t[9..$#t]; $tot=$#t -8; next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"' $1 >${1}.missing.maf.txt

# hmp
perl -ne 'BEGIN{print join("\t", qw(chr pos ID Missing_rate MAF Heterozygosity)), "\n"} next if /\#/; chomp; @t=split /\s+/,$_; $missing=0; %h=(); map{ if(/N/){$missing++}else{$h{$_}++} }@t[11..$#t]; $ref=$alt=$het=0; $hk=""; map{@arr=split //,$_; $hk=$_ if @arr==2 and  $arr[0] ne $arr[1] }keys %h; @homo_keys = (); map{push @homo_keys, $_ unless $_ eq $hk}keys %h; $ref=$h{$homo_keys[0]} if exists $h{$homo_keys[0]}; $alt=$h{$homo_keys[1]} if exists $h{$homo_keys[1]}; $het=$h{$hk} if exists $h{$hk}; $tot = $#t - 10;   next if ($ref+$alt)==0;  $maf=($ref+0.5*$het)/($ref+$alt+$het); $maf=1-$maf if $maf>0.5; $miss_rate=$missing/$tot; $het_rate=$het/($ref+$alt+$het), "\n";  print join("\t", @t[0..2], $miss_rate, $maf, $het_rate), "\n"' $1 >${1}.missing.maf.txt