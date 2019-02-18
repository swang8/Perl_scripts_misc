args = commandArgs(trailingOnly=TRUE)
file = args[1]
#file="http://download.txgen.tamu.edu/shichen/shuyu/TXE_b2/evaluate_imputation/accuracy_summary.txt"
data = read.table(file, header=T, sep="\t")

library(ggplot2)

p = ggplot(data, aes(Allele_freq, Accuracy))
p = p + geom_bar(stat="identity", position="dodge", aes(fill=as.factor(GP_cutoff))) + theme_light() +  
  theme(plot.background = element_rect(fill = "white")) +
  guides(fill = guide_legend(title = "GP cutoff")) + 
  theme(axis.text.x = element_text(angle = 45, hjust=1), axis.text=element_text(size=12),axis.title=element_text(size=14,face="bold"))

pdfout = paste(file, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")
