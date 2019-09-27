# For vcf: transform 0/0, 0/1, 1/1 to A, B and H; missing to N.
vcf=$1
perl -ne 'if(/\#/){next unless /\#CHR/} chomp; @t=split /\s+/,$_; if(/\#CHR/){print join("\t", @t[0,1,3,4,9..$#t]),"\n"; next} map{if($t[$_]=~/0\/0/){$t[$_]="A"}elsif($t[$_]=~/0\/1/){$t[$_]="H"}elsif($t[$_]=~/1\/1/){$t[$_]="B"}else{$t[$_]="N"} }9..$#t; print join("\t", @t[0,1,3,4,9..$#t]),"\n";'  $vcf
