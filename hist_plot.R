opts = commandArgs(trailingOnly=T)
file = opts[1]

d = read.table(file, header=F, sep="\t")
pdf_file = paste(file, "hist.plot.pdf", sep=".")
pdf(pdf_file)
hist(d[d[,4]<2000, 4], col="slateblue", main=file, xlab="Insert length, bp")
dev.off()

