INPUT=$1

perl -ne '$n++; if($n<=11300868){chomp; @t=split /\s+/,$_; $h{$t[0]}=[@t]}else{chomp; ($ctg, $pos)=(); ($ctg, $pos)=($1, $2) if /(\S+)_(\d+)$/; unless(exists $h{$ctg}){print $_, "\tNA\n"}  next unless $ctg=~/\S/ and exists $h{$ctg};  @arr=@{$h{$ctg}};  $strand=$arr[4]<$arr[5]?1:-1; $np1=$arr[4] + $strand * ($pos-$arr[1]); $np2=$arr[7] + $strand * ($pos-$arr[1]); print join("\t", $ctg, $pos, $arr[3], $np1, $arr[6], $np2), "\n"  }'  /home/shichen.wang/data4/wheat_CSS/blat_pseudoM_V1.0/CSS_to_pseudoMV1.0.bed  $INPUT  >${INPUT}_IWGSC_v1.coord.txt

perl -ne 'chomp; @t=split /\s+/,$_; if(@t > 2){@arr=map{ join("_", @t[$_, $_+1])}(0,2,4); print join("\t", @arr), "\n"; next } print $_, "\n"' ${INPUT}_IWGSC_v1.coord.txt  >${INPUT}_IWGSC_v1.coord_.txt



# input format
# 10059824_5bl_2205
# 10059824_5bl_2305
