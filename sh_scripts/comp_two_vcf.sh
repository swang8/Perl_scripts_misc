perl -e '@fs=@ARGV; $read_vcf=sub{$f=shift; open(IN, $f) or die $!; my %h;  while(<IN>){next if /\#/; $id=join(" ", $1, $2) if /^(\S+)\s+(\S+)/; $h{$id}=1}; close IN; return %h};  %ha=$read_vcf->($fs[0]); %hb=$read_vcf->($fs[1]); $n=0; map{$n++ if exists $hb{$_}; print STDERR $_, "\n" if exists $hb{$_} }keys %ha;  $cha=scalar (keys %ha); $chb=scalar(keys %hb); print $cha-$n, "\t", $n, "\t", $chb-$n, "\n"   ' $1 $2