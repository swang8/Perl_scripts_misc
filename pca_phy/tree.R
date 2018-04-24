if("ape" %in% rownames(installed.packages()) == FALSE) {install.packages("ape", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
library("ape")
args = commandArgs(trailingOnly=TRUE)
geno_file  = args[1]
phy_file = args[2]
#data <- read.table("genotyping_trans.csv", header=T, sep=",")
data <- read.table(geno_file, header=T, sep=",")
rownames(data) = data[, 1]
data = data[, -1]
dis <- dist(data)
tree <- njs(dis)
#write.tree(tree, "divers_tree.phy")
write.tree(tree, phy_file)
