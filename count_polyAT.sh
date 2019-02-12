f=$1
output=`zcat $f |perl -ne '$n++; if($n==2){$m++; $at++ if /A{10,}/ or /T{10,}/ or /A{6,}$/ or /T{6,}$/} $n=0 if $n==4; END{print $at, "\t", $m, "\n"} ' `
echo $f $output
