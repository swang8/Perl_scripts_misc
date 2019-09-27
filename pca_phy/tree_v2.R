if("ape" %in% rownames(installed.packages()) == FALSE) {install.packages("ape", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("vcfR" %in% rownames(installed.packages()) == FALSE) {install.packages("vcfR", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
if("poppr" %in% rownames(installed.packages()) == FALSE) {install.packages("poppr", repos="http://cran.revolutionanalytics.com", dependencies = TRUE)}
library("ape")
library("vcfR")
library("poppr")
args = commandArgs(trailingOnly=TRUE)
vcf_file  = args[1]
pop_file = args[2]
phy_file = args[3]

rubi.VCF <- read.vcfR(vcf_file)
pop.data <- read.table(pop_file, sep = ",", header = F)

if (! all(colnames(rubi.VCF@gt)[-1] == pop.data$V1)) {print("Some samples have no group names!"); exit(1)}

gl.rubi <- vcfR2genlight(rubi.VCF)

ploidy(gl.rubi) <- 2

pop(gl.rubi) <- pop.data$V2

tree <- aboot(gl.rubi, tree = "upgma", distance = bitwise.dist, sample = 100, showtree = F, cutoff = 50, quiet = T)

write.tree(tree, file=phy_file)
