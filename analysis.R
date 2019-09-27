if("ape" %in% rownames(installed.packages()) == FALSE) {install.packages("ape", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("vcfR" %in% rownames(installed.packages()) == FALSE) {install.packages("vcfR", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("poppr" %in% rownames(installed.packages()) == FALSE) {install.packages("poppr", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("RColorBrewer" %in% rownames(installed.packages()) == FALSE) {install.packages("RColorBrewer", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("igraph" %in% rownames(installed.packages()) == FALSE) {install.packages("igraph", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("ggplot2" %in% rownames(installed.packages()) == FALSE) {install.packages("ggplot2", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("reshape2" %in% rownames(installed.packages()) == FALSE) {install.packages("reshape2", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
library(reshape2)
library("ape")
library("vcfR")
library("poppr")
library("RColorBrewer")
library(igraph)
library(ggplot2)


# get input form the command line: 1. VCF 2. pop
args = commandArgs(trailingOnly=TRUE)
vcf_file  = args[1]
pop_file = args[2]

phy_file = paste(vcf_file, ".phy", sep="")

# read VCF
rubi.VCF <- read.vcfR(vcf_file)
pop.data <- read.table(pop_file, sep = ",", header = F)

# check if samples in the vcf are matching samples in the pop
if (! all(colnames(rubi.VCF@gt)[-1] == pop.data$V1)) {print("Some samples have no group names!"); exit(1)}

# transform into genelight obj
gl.rubi <- vcfR2genlight(rubi.VCF)
ploidy(gl.rubi) <- 2
pop(gl.rubi) <- pop.data$V2


# build a tree using bitwise.dist
tree <- aboot(gl.rubi, tree = "upgma", distance = bitwise.dist, sample = 100, showtree = F, cutoff = 50, quiet = T)
write.tree(tree, file=phy_file)

# plot the tree
tree.pdf = paste(phy_file, ".pdf", sep="")
pdf(tree.pdf)
cols <- brewer.pal(n = nPop(gl.rubi), name = "Dark2")
plot.phylo(tree, cex = 0.8, font = 2, adj = 0, tip.color =  cols[pop(gl.rubi)])
nodelabels(tree$node.label, adj = c(1.3, -0.5), frame = "n", cex = 0.8,font = 3, xpd = TRUE)
legend('topleft', legend = pop(gl.rubi), fill = cols, border = FALSE, bty = "n", cex = 2)
axis(side = 1)
title(xlab = "Genetic distance (proportion of loci that are different)")
dev.off()

# Minimum spanning networks
#Another useful independent analysis to visualize population structure is a minimum spanning network (MSN). MSN clusters multilocus genotypes (MLG) by genetic distances between them. Each MLG is a node, and the genetic distance is represented by the edges. In high throughput sequencing studies, where marker density is high, each sample typically consists of a unique genotype.

rubi.dist <- bitwise.dist(gl.rubi)
rubi.msn <- poppr.msn(gl.rubi, rubi.dist, showplot = FALSE, include.ties = T)

node.size <- rep(2, times = nInd(gl.rubi))
names(node.size) <- indNames(gl.rubi)
vertex.attributes(rubi.msn$graph)$size <- node.size

set.seed(9)
pdf(pase(vcf_file, ".msn.pdf", sep=""))
plot_poppr_msn(gl.rubi, rubi.msn , palette = brewer.pal(n = nPop(gl.rubi), name = "Dark2"), gadj = 70)
dev.off()

#Principal components analysis
#A principal components analysis (PCA) converts the observed SNP data into a set of values of linearly uncorrelated variables called principal components that summarize the variation between samples. We can perform a PCA on our genlight object by using the glPCA function.

rubi.pca <- glPca(gl.rubi, nf = 3)

pdf(pase(vcf_file, ".PCA-EIG.pdf", sep=""))

barplot(100*rubi.pca$eig/sum(rubi.pca$eig), col = heat.colors(50), main="PCA Eigenvalues")
title(ylab="Percent of variance\nexplained", line = 2)
title(xlab="Eigenvalues", line = 1)
dev.off()

rubi.pca.scores <- as.data.frame(rubi.pca$scores)
rubi.pca.scores$pop <- pop(gl.rubi)
set.seed(9)
p <- ggplot(rubi.pca.scores, aes(x=PC1, y=PC2, colour=pop)) 
p <- p + geom_point(size=2)
p <- p + stat_ellipse(level = 0.95, size = 1)
p <- p + scale_color_manual(values = cols) 
p <- p + geom_hline(yintercept = 0) 
p <- p + geom_vline(xintercept = 0) 
p <- p + theme_bw()

pdf(pase(vcf_file, ".PCA.pdf", sep=""))
print(p)
dev.off()

#DAPC
#The DAPC is a multivariate statistical approach that uses populations defined a priori to maximize the variance among populations in the sample by partitioning it into between-population and within-population components. DAPC thus maximizes the discrimination between groups.

pnw.dapc <- dapc(gl.rubi, n.pca = 3, n.da = 2)
pdf(pase(vcf_file, ".DAPC.pdf", sep=""))
scatter(pnw.dapc, col = cols, cex = 2, legend = TRUE, clabel = F, posi.leg = "bottomleft", scree.pca = TRUE,
        posi.pca = "topleft", cleg = 0.75)
dev.off()

#The DAPC object we created includes the population membership probability for each sample to each of the predetermined populations. To visualize the posterior assignments of each sample, we use a composite stacked bar plot (compoplot). A compoplot illustrates the probability of population membership on the y-axis. Each sample is a bin on the x-axis, and the assigned probability of population membership is shown as a stacked bar chart with clusters or populations shown in color.

dapc.results <- as.data.frame(pnw.dapc$posterior)
dapc.results$pop <- pop(gl.rubi)
dapc.results$indNames <- rownames(dapc.results)

dapc.results <- melt(dapc.results)

colnames(dapc.results) <- c("Original_Pop","Sample","Assigned_Pop","Posterior_membership_probability")

p <- ggplot(dapc.results, aes(x=Sample, y=Posterior_membership_probability, fill=Assigned_Pop))
p <- p + geom_bar(stat='identity') 
p <- p + scale_fill_manual(values = cols) 
p <- p + facet_grid(~Original_Pop, scales = "free")
p <- p + theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 8))

pdf(pase(vcf_file, ".COMP.pdf", sep=""))
print(p)
dev.off()


