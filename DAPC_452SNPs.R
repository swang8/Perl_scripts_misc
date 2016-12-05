# R script to run DAPC in package adegenet
# by SW
library("adegenet")

# input file of genotype data
# This script assume the format is like this:
#     code,country,status,snp1,snp2,...
#     AUS102,Australia,cultivar,1,0,2...
#     AUS103,Australia,cultivar,1,1,2...
#     AUS104,Europe,cultivar,0,0,2...
#     ........
genotype_file = "452SNPs_PCA_input_addPanle.csv";

# group file for each accession
# Format:
# AUS102 CENTRAL_winter
# AUS103 CENTRAL_winter
# AUS104 Europe_winter
# ......
group_file = "grp_5.txt";

## check if the input files exist ##
filewarningflag <- "no"
filewarnings <- vector()
if (!file.exists(genotype_file)) {
     filewarningflag <- "yes"
     filewarnings<-append(filewarnings,genotype_file)
}
if (!file.exists(group_file)) {
     filewarningflag <- "yes"
     filewarnings<-append(filewarnings,group_file)
}

if (filewarningflag == "yes") {
    print ("The following file(s) could not be found in the current  
directory:")
    print (filewarnings)
    stop()
}

### output file
outfilepdf<-paste(genotype_file,"DAPC.pdf",sep="_")

### read input files

genotype <- read.table(genotype_file, header=T, sep=",", na="NA")
idgroups <- read.table(group_file, header=F, sep="\t")

# prepare genotype file for dapc
accession_ids <- genotype[,1]
rownames(genotype) <- accession_ids
snp_start = 4 # change this number to fit your own file format
genotype <- genotype[, snp_start:length(colnames(genotype))]

# NA replacement
na_replace <- function(vec) {
 #      m <- mean(vec, na.rm = TRUE)
        m <- -1;
        vec[is.na(vec)] <- m
        return(vec)
}
genotype <- apply(genotype, 1, na_replace)
genotype <- apply(genotype, 1, as.numeric)
# transform to genind object, this would take long time for big dataset
groups <- factor(idgroups[,2])
genotype_genind_obj <- genind(genotype, pop=groups, type="codom")
#genotype_genind_obj <- na.replace(genotype_genind_obj, mean)

# run PCA and k-means cluster
# will be asked for the nubmer of PCs to re retained
# and the number of clusters if not pre-assign the n.pca and n.clust
num_clusters <- length(levels(groups)) + 1;
genotype_clusters <- find.clusters(genotype_genind_obj)

# DAPC
genotype_dapc <- dapc(genotype_genind_obj, genotype_clusters$grp)

# colors and pch for plot
cl <- colors();
rownames(idgroups) <- idgroups[,1]
grpnames <- levels(groups)
#grpcolor <- rainbow(length(grpnames));
grpcolor=character(0);
for (i in 1:length(grpnames)){grpcolor = c(grpcolor, cl[5*i+27])};
names(grpcolor) <- grpnames
grpcolor["MIDWEST_winter"] = "deepskyblue2"
grpcolor["Landraces"] = "red"
grppch <- seq(1:length(grpnames))
grppch[12] = 15
grppch[15] = 12
names(grppch) <- grpnames
indpch <- numeric(0)
indcolor <- character(0)
fillcolor <- character(0)
for(i in 1:length(accession_ids)){
  grp <- idgroups[accession_ids[i], 2]
  indcolor <- c(indcolor, grpcolor[grp])
  fillcolor <-c(fillcolor, grpcolor[grp])
  indpch <- c(indpch, grppch[grp])
}


# plot
pdf(outfilepdf, width=18, height=18)
scatter(genotype_dapc, col="white", scree.da=0, pch="", cstar=0, clab=0, cex=3, bg="white")
points(genotype_dapc$ind.coord[, 1], genotype_dapc$ind.coord[, 2], pch = indpch, col=as.character(indcolor),cex=1.5)
# legends, adjust x y to better fit your plot
legend(x=-18,y=16, grpnames, col=as.character(grpcolor), pch=grppch,cex=2.4,bty="n")

# add dot for accessions used to discover SNPs
panel <- c("G3266","G332","G804","G1003","G966","G993","G998","G3616","G3169","G2421","G3518","G3067")
get_coordinates <- function(ac_ids, panel, PCA){
  coord <- numeric(0);
  for(i in panel){
    p <- PCA[ac_ids==i]
    coord <- c(coord, p)
  }
  return(coord)
}
pca1_panel <- get_coordinates(accession_ids, panel, PCA1)
pca3_panel <- get_coordinates(accession_ids, panel, PCA3)
pca2_panel <- get_coordinates(accession_ids, panel, PCA2)
points(pca1_panel, pca2_panel, pch="*", col=rgb(red=0, green=0, blue=255, alpha=255,max=255), cex=4)

dev.off()
# plot(PCA1, PCA2, pch = indpch, col=as.character(indcolor),cex=2)
# points(PCA1[indcolor=="red"], PCA2[indcolor=="red"], pch = 15, col=rgb(red=255, green=0, blue=0, alpha=120, max=255),cex=2)
# 

# save image so you can save some time if want to change color after this
imagefile = paste(genotype_file,"Rdata",sep=".")
save.image(file=imagefile)

#q(save="no")



