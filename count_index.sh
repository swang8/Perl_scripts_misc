zcat $1 | perl -ne '$n++; if($n==1){$index=$1 if /1:N:0:(\S+)/; $h{$index}++} $n=0 if $n==4; END{map{print $_, "\t", $h{$_}, "\n"}sort {$h{$b} <=> $h{$a}}keys %h}'
