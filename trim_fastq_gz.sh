zcat $1 | perl -ne 'chomp; $n++; if($n==2 or $n==4){$_=substr($_, 0, 75)} $n=0 if $n==4; print $_, "\n"' 
