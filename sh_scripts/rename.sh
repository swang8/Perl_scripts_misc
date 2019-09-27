proj=$1
perl -e '@fs=<agseq_*>; $p=shift;  map{$f=$_; $o=$f; $o=~s/^agseq/$p/; $cmd="mv $f $o"; print $cmd, "\n"; system($cmd)}@fs' $proj
