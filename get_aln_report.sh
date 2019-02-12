## get numbers from bowtie2 align report
## Example:
## 2853612 reads; of these:
##   2853612 (100.00%) were paired; of these:
##     884634 (31.00%) aligned concordantly 0 times
##     1807820 (63.35%) aligned concordantly exactly 1 time
##     161158 (5.65%) aligned concordantly >1 times
##     ----
##     884634 pairs aligned concordantly 0 times; of these:
##       27309 (3.09%) aligned discordantly 1 time
##     ----
##     857325 pairs aligned 0 times concordantly or discordantly; of these:
##       1714650 mates make up the pairs; of these:
##         1182234 (68.95%) aligned 0 times
##         399602 (23.31%) aligned exactly 1 time
##         132814 (7.75%) aligned >1 times
## 79.29% overall alignment rate

perl -ne 'BEGIN{$f=$ARGV[0]}chomp; push @arr, $_ if /^\s+\d+/ or /^\d+/; END{ map{push @p, $1 if /\s{0,}(\d+)/}@arr; $tot=$p[0]*2; $aln=0; map{$aln += $_*2}@p[3,4,6]; map{$aln += $_}@p[10,11]; print join("\t", $f, $tot, $aln, sprintf("%.02f", 100*$aln/$tot) ), "\n" }'  $1 

