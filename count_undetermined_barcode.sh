zcat $1 | perl -ne '$n++; if($n==1){$bar=$1 if /0:(\S+)$/; $bar=~s/\+/\t/g;  $h{$bar}++} $n=0 if $n==4; END{map{$s += $_}values %h;   map{print $_, "\t", $h{$_}, "\t", sprintf("%.2f",$h{$_}/$s), "\n"}sort{$h{$b} <=> $h{$a}}keys %h}' >undetermined_barcode_pairs.txt

perl -ne 'chomp; @t=split /\s+/,$_; $h{$t[0]} += $t[2]; $g{$t[1]} += $t[2]; END{ map{$sum+=$_}values %h; print "Total\t$sum\n"; print STDERR "Total\t$sum\n";  map{ print $_, "\t", $h{$_}, "\n"}sort{$h{$b} <=> $h{$a}}keys %h; map{ print STDERR $_, "\t", $g{$_},"\n"}sort{$g{$b} <=> $g{$a}}keys %g;  }' undetermined_barcode_pairs.txt  1>index1_count.txt 2>index2_count.txt


