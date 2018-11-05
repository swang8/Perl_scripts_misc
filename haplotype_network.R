library(ape)
library(pegas)
opts = commandArgs(trailingOnly=T)
input1 = opts[1]

#input1 = "sr33_var.vcf.imputed.fasta"
d <- ape::read.dna(input1, format='fasta')

input2 = opts[2]
#input2 = "sr33_hap.ids.pop"
grp = read.table(input2, header=F, sep="\t")
popName = as.character(grp$V2)

e <- dist.dna(d)
h <- pegas::haplotype(d)
h <- sort(h, what = "label")
(net <- pegas::haploNet(h))
ind.hap<-with(
stack(setNames(attr(h, "index"), rownames(h))),
table(hap=ind, pop=popName[values])
)

name = sub("_region.fasta", "", input1)
pdf(paste(name, "hap_net2.pdf", sep="_"))
par(mar=c(1,1,3,1))
layout(matrix(c(1,1,2,2), 2, 2, byrow = TRUE))
plot(net, size=attr(net, "freq"), scale.ratio=0.2, pie=ind.hap, main=name)
plot.new()
legend("topleft", colnames(ind.hap), col=rainbow(ncol(ind.hap)), pch=19, ncol=4)
dev.off()
