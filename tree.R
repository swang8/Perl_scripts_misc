library("ape")
opts = commandArgs(trailingOnly = T)
f = opts[1]
data <- read.table(f, header=T, sep=",")
data <- t(data)
dis <- dist(data)
tree <- njs(dis)
write.tree(tree, paste(f, "divers_tree.phy", sep="_") )
