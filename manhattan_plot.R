opts = commandArgs(trailingOnly=T)

input = opts[1]

data = read.table(input, sep=",", header=T)

data = data[order(data[,2], data[,3]),]

#chrs = paste(rep(1:7, each=2), "D", sep="")

data$chrName = data$Chromosome

nchrs = length(unique(data$Chromosome))

newPos = integer(nchrs)
tb = table(data$chrName)
tb_cumsum = cumsum(tb)
for (i in 1:length(tb_cumsum)) {
  newPos[i] = tb_cumsum[i] - as.integer(tb[i]/2)
}

cols = character()
for (i in 1:length(tb)){
  c = "slateblue"
  if (i %% 2 > 0) {c="salmon"}
  cols = c(cols, rep(c, tb[i]))
}

pdf(paste(input, "pdf", sep="."), width=19, height = 5)
par(mar=c(5,5,1,1))
plot(1:nrow(data), -1*log(data[, 4])/log(10), pch=20, col=cols, axes=F, xlab="Chromosomes", ylab="-log10(p)", cex.lab=2)
abline(h=5, col="gray50", lty=3)
axis(1, at = newPos, labels=1:nchrs)
axis(2)
box()
dev.off()


