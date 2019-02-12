F=$1
K=$2
# step 1
/home/shichen.wang/Tools/KMC/bin/kmc -k$K -m30 -t10 -cs10000000  -fm $F ${F}.K${K}.kmc ./tmp
# step 2
/home/shichen.wang/Tools/KMC/bin/kmc_dump ${F}.K${K}.kmc ${F}.K${K}.freq.txt 
# step 3
sort -k2,2nr ${F}.K${K}.freq.txt >${F}.K${K}.freq.sorted.txt
