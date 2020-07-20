# calculates the differential expression of miRNA using edgeR
# USAGE: differential_expression.R <Mature_miRNA_expression.xls> <output dir> <analysis name> <samples (s1,s2)> <groups (g1,g2)> <pairs (optional)>

stdin <- commandArgs(TRUE)

if(length(stdin) < 5 || length(stdin) > 6){
	stop("ERROR! Incorrect number of arguments. \nUSAGE: differential_expression.R <Mature_miRNA_expression.xls> <output dir> <analysis name> <samples (s1:s2)> <groups (g1:g2)> <pairs (optional)>")
}
raw.exprs.path <- stdin[1]
output.dir <- stdin[2]
label <- stdin[3]
samples <- make.names(unlist(strsplit(stdin[4],":")))
groups <- unlist(strsplit(stdin[5],":"))
if(length(stdin) > 5){
	pairs <- unlist(strsplit(stdin[6],":"))
}
samples
library(edgeR)

# load expression table
expression.raw <- read.table(raw.exprs.path, sep="\t",header=T,stringsAsFactor=F)
# assign unique mature_precursor id to each row
#row.names(expression.raw)<-paste(expression.raw$Mature.miRNA,expression.raw$Precursor,sep="_")
row.names(expression.raw) <- expression.raw$Mature.miRNA

# extract samples used in this comparison
expression.raw.samples <- expression.raw[,samples]
#head(expression.raw.samples)

expression.raw.samples.dglist <- DGEList(expression.raw.samples, group=groups)
# only keep miRNA if there are > 5 counts in at least half of the samples
#expression.raw.samples.dglist <- expression.raw.samples.dglist[rowSums(cpm(expression.raw.samples.dglist) > 5) >=2,]
expression.raw.samples.dglist <- expression.raw.samples.dglist[rowSums(cpm(expression.raw.samples.dglist) > 5) > (length(expression.raw)-2)/2,]
expression.raw.samples.dglist <- calcNormFactors(expression.raw.samples.dglist)
#png(paste(output.dir,"/",label,".MDS.png",sep=""),width=1280,height=960,res=150)
pdf(paste(output.dir,"/",label,"_plots.pdf",sep=""),width=11,height=8.5)
par(mar = c(6,6,5,3))
if (ncol(expression.raw.samples.dglist) >= 3) {
  plotMDS(expression.raw.samples.dglist, main=paste("MDS plot for ",label,sep=""))
}
#dev.off()

# create design matrix
if(length(stdin) > 5){
	# For Paired Groups:
	design<-model.matrix(~pairs+expression.raw.samples.dglist$samples$group)
}else{
	# For Unpaired Groups:
	design<-model.matrix(~expression.raw.samples.dglist$samples$group)
}
rownames(design) <- rownames(expression.raw.samples.dglist$samples)
colnames(design)[length(colnames(design))] <- label

# estimate common dispersions
expression.raw.samples.dglist <- estimateGLMCommonDisp(expression.raw.samples.dglist, design)

# tagwise dispersion preferred
expression.raw.samples.dglist.tagdis <- estimateGLMTagwiseDisp(expression.raw.samples.dglist, design)
names(expression.raw.samples.dglist.tagdis)
head(expression.raw.samples.dglist.tagdis$tagwise.dispersion)
summary(expression.raw.samples.dglist.tagdis$tagwise.dispersion)

# GLM model for differentially expressed miRNAs
glmfit.expression.raw.dglist.tagdis <- glmFit(expression.raw.samples.dglist.tagdis, design, dispersion=expression.raw.samples.dglist.tagdis$tagwise.dispersion)
lrt.expression.raw.dglist.tagdis <- glmLRT(glmfit.expression.raw.dglist.tagdis)

# normalized expression
normcnt <- round(cpm(expression.raw.samples.dglist.tagdis, normalized.lib.sizes=T))
nmexpr.eRout.tagdis <- merge(normcnt, topTags(lrt.expression.raw.dglist.tagdis,n=10000), by.x="row.names", by.y="row.names")
names(nmexpr.eRout.tagdis)[1] <- "Mature.ID"
nmexpr.eRout.tagdis <- nmexpr.eRout.tagdis[order(nmexpr.eRout.tagdis$PValue),]
write.table(nmexpr.eRout.tagdis, paste(output.dir,"/",label,".differential_expression.xls",sep=""),sep="\t",quote=F,row.names=F)

# plot results
#png(paste(output.dir,"/",label,".FDR.volcano_plot.png",sep=""),width=1280,height=960,res=150)
plot(nmexpr.eRout.tagdis$logFC, -log10(nmexpr.eRout.tagdis$FDR), col=ifelse(nmexpr.eRout.tagdis$FDR<0.05,"red","black"),main="FDR volcano plot",xlab="log2FC",ylab="-log10(FDR)")
#dev.off()

#png(paste(output.dir,"/",label,".Pvalue.volcano_plot.png",sep=""),width=1280,height=960,res=150)
plot(nmexpr.eRout.tagdis$logFC, -log10(nmexpr.eRout.tagdis$PValue),col=ifelse(nmexpr.eRout.tagdis$PValue<0.01,"red","black"),main="P-value volcano plot",xlab="log2FC",ylab="-log10(Pvalue)")
#dev.off()

#png(paste(output.dir,"/",label,".Pvalue_distribution.png",sep=""),width=1280,height=960,res=150)
hist(nmexpr.eRout.tagdis$PValue,breaks=20,xlab="P Value",ylab="Frequency",main="P-value distribution")
dev.off()


