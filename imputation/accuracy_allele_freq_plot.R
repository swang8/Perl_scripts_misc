
##
#file="http://download.txgen.tamu.edu/shichen/shuyu/TXE_b2/evaluate_imputation/accuracy_summary.txt"

opts = commandArgs(trailingOnly=T);
file = opts[1]

data = read.table(file, header=T, sep="\t")

library(ggplot2)
pdf_file = paste(file, "pdf", sep=".")
pdf(pdf_file, height=10, width=20)
p = ggplot(data, aes(Allele_freq, Accuracy))
p + geom_bar(stat="identity", position="dodge", aes(fill=as.factor(GP_cutoff))) +  
  guides(fill = guide_legend(title = "GP cutoff")) + 
  theme(axis.text.x = element_text(angle = 45, hjust=1), axis.text=element_text(size=12),axis.title=element_text(size=14,face="bold"))
dev.off()
