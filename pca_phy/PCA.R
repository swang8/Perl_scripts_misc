args = commandArgs(trailingOnly=TRUE)
#genotype_file = "genotyping_trans.csv"
genotype_file = args[1]
#group_file = "groups.dat"
group_file = args[2]
### read input files
genotype <- read.table(genotype_file, header=T, sep=",", na="NA")
idgroups <- read.table(group_file, header=F, sep="\t")

# prepare genotype file for pca
accession_ids <- genotype[,1]

snp_start = 2 # change this number to fit your own file format
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

rownames(genotype) <- accession_ids

gn.pca = prcomp(genotype)

gn.grps = as.character(idgroups[which(idgroups$V1 %in% accession_ids), 2])
#colorsfile<-"groups.color"
colorsfile <- args[3]

grp_col = read.delim(colorsfile, header=F)
grp_col$V1 = as.character(grp_col$V1)
grp_col$V2 = as.character(grp_col$V2)

ind_col = character(length(gn.grps))
for (i in 1:length(gn.grps)){
  ind_col[i] = grp_col$V2[which(grp_col$V1 %in% gn.grps[i])]
}

var_explained = summary(gn.pca)
var_explained_PC123 = var_explained$importance[2,1:3] * 100

# plot
pdf("PCA.pdf", width=10, height=10)
plot_pca = c(1, 2)
x = gn.pca$x[,  plot_pca[1]]
y = gn.pca$x[,  plot_pca[2]]
x_lab_txt = paste("PC", plot_pca[1], sep="")
x_exp_var = paste("variation explained ", var_explained_PC123[plot_pca[1]], "%",sep="")
y_lab_txt = paste("PC", plot_pca[2], sep="")
y_exp_var = paste("variation explained ", var_explained_PC123[plot_pca[2]], "%",sep="")

par(mar=c(5,5,1,1))
plot(x, y, col=ind_col, bg=ind_col, pch=21, cex=2, xlab=paste(x_lab_txt, x_exp_var, sep=","), ylab=paste(y_lab_txt, y_exp_var, sep=","), main="", cex.lab=2)

legend("bottomleft", legend=grp_col$V1, pt.bg = as.character(grp_col$V2), col =  as.character(grp_col$V2), pch=21, bty="n", cex=1, pt.cex=2, ncol=1)

dev.off()

