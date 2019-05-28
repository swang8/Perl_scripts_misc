opt=commandArgs(trailingOnly=T)

file=opt[1]

d = read.table(file, header=F, sep="\t")
td = t(d)

write.csv(td,file=paste(file, "transposed", sep="_"), row.names=F, col.names=F, quote=F)
