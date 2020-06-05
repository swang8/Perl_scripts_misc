#!/bin/bash
download_root="download.txgen.tamu.edu/shichen/pca_phy"

original_geno_file=$1
sample_file=$2

# create genotyping data for samples
echo `date` "**** extracting data from the original genotyping file ..."
new_geno_file=${original_geno_file}_${sample_file}
perl -e '($sample, $geno) = @ARGV;  open(S, $sample) or die; while(<S>){chomp; s/\"//g; @t=split /,/, $_; $h{$t[0]}=$t[1]} close S; open(G, $geno) or die; $l=0;  while(<G>){$l++; if($l==1){print $_; next}; s/\"//g;  $id=$1 if /^(\S+?)\,/;  print $_ if exists $h{$id} } close G;'  $sample_file $original_geno_file >$new_geno_file

# create new groups.dat
groups_dat=groups.dat.${sample_file}
perl -ne 'chomp; s/\s//g; @t=split /,/, $_; print join("\t", @t), "\n"' ${sample_file} >${groups_dat}

# create new groups.color
color_file="colors.csv"
if [ ! -f "get_colors.R" ]; then
  wget  ${download_root}/get_colors.R -olog
fi
Rscript get_colors.R

groups_color=groups.color.${sample_file}
perl -ne 'chomp; s/\s//g; @t=split /\,/,$_; $h{$t[1]}++; END{open(COL, "colors.csv") or die $!; @colors=(); while(<COL>){chomp; push @colors, $_} close COL; @colors=@colors[1..$#colors]; $col_num = scalar @colors;  %col={}; while(keys %col < (scalar keys %h)){$k=int(rand($col_num)); $col{$k}=1 if $k < $col_num} @picked = @colors[keys %col]; @grps=keys %h;  map{print $grps[$_], "\t", $picked[$_], "\n"}0..$#grps; }' ${sample_file} >${groups_color}

#rm get_colors.R colors.csv

# run tree.R
echo `date` "**** generating the tree ..."
phy_file=${sample_file}.divers_tree.phy
if [ ! -f "tree.R" ]; then
  wget  ${download_root}/tree.R -olog
fi

Rscript tree.R ${new_geno_file} $phy_file
#rm tree.R

## add groupinfo to the sample name
echo `date` " **** adding group info to the sample name ..."
cp ${groups_dat} ${groups_dat}.original
perl -ne 'chomp; @t=split /\t/,$_; print $t[0]."_".$t[1], "\t", $t[1], "\n"' ${groups_dat}.original >${groups_dat}
cp $phy_file ${phy_file}.original
perl -e '$group = shift; $tree=shift; open(G, $group) or die; while(<G>){chomp; @t=split /\t/, $_; $h{$t[0]} = $t[0]."_".$t[1];} close G; $r = `cat $tree`;  @p=split /,/, $r;  foreach $str (@p){$str=~s/^\(+//; @arr=split /:/, $str; $id=$arr[0]; if(exists $h{$id}){$r=~s/$id:/$h{$id}:/}} print $r' ${groups_dat}.original  ${phy_file}.original >$phy_file


# run PCA.R
echo `date` "**** Running PCA ..."
if [ ! -f "PCA.R" ]; then
  wget  ${download_root}/PCA.R -olog
fi
Rscript PCA.R ${new_geno_file} ${groups_dat} ${groups_color}
#rm PCA.R

# run color_phylogenetic_tree.R
echo `date` "**** plot the tree ..."
if [ ! -f "color_phylogenetic_tree.R" ]; then
  wget  ${download_root}/color_phylogenetic_tree.R  -olog
fi
Rscript color_phylogenetic_tree.R $phy_file ${groups_dat} ${groups_color}
#rm color_phylogenetic_tree.R

echo "****"
echo "The tree is plotted: ${phy_file}.tree.pdf"
echo `date` "Done!"
