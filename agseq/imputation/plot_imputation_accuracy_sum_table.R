args = commandArgs(trailingOnly=TRUE)
file = args[1]
#file="http://download.txgen.tamu.edu/shichen/Thomson/18334Tho/imputation/imp_eval/imputation_eval.2.tsv.sum.table.csv"
library(ggplot2)

data = read.table(file, header=F, sep=",", stringsAsFactors =F)

names = as.character( unlist(list(data[1, ])[[1]]) )

data = data[-1, ]

data = as.data.frame(sapply(data, as.numeric) )

for (i in 1:nrow(data)){
  data[i, 2:11]  = data[i, 2:11] / data[i, 12]
}

gp = numeric(100)
type = character(100)
acc =  numeric(100)

index = 0
for (i in 1:10) {
  for (j in 2:11){
    index = index + 1
    gp[index] = data$V1[i]
    type[index] = names[j]
    acc[index] = data[i, j]
  }
}

df = data.frame(GP=gp, Type=type, Proportion=acc)

p = ggplot(df, aes(Type, Proportion))
p = p + geom_bar(stat="identity", position="dodge", aes(fill=as.factor(GP))) + theme_light() +
  theme(plot.background = element_rect(fill = "white")) +
  guides(fill = guide_legend(title = "GP cutoff")) +
  theme(axis.text.x = element_text(angle = 45, hjust=1), axis.text=element_text(size=12),axis.title=element_text(size=14,face="bold"))

pdfout = paste(file, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")

pdfout = paste(file, "accuracy_sum_up", "pdf", sep=".")

colnames(data) = names
print(data)

# add genotyped_percentage line to the accuracy plot
geno_percent_file="GP_cutoff_remain.txt"

if (!file.exists(geno_percent_file)){
  p = ggplot(data = data, aes(GP, Accuracy)) + 
    geom_bar(stat="identity", fill="salmon") + ggtitle("Imputation accuracy") +
    coord_cartesian(ylim=c(min(data["Accuracy"])-0.05, 1)) +
    scale_x_continuous("Genotype probability cutoff", breaks = data$GP ) + 
    theme(axis.text=element_text(size=18),axis.title=element_text(size=20,face="bold"), plot.title = element_text(size=25, face="bold", hjust = 0.5))
} else {
  geno_remain = read.table(geno_percent_file, header=F, sep="\t")
  newd = subset(data, select=c("GP", "Accuracy"))
  newd["remain"] = geno_remain$V2
  print(newd)
  p <- ggplot(newd, aes(x = GP)) + coord_cartesian(ylim=c(min(newd["Accuracy"])-0.05, 1)) + ggtitle("Imputation accuracy")
  p <- p + geom_bar(aes(y=Accuracy), stat="identity", fill="salmon")
  p <- p + geom_line(aes(y = remain), color="slateblue") + geom_point(aes(y = remain),color="slateblue")

  p <- p + scale_y_continuous(sec.axis = sec_axis(~.*1, name = "Genotyped ratio"))
  
  p <- p + theme(legend.position = c(0.1, 0.9)) +
       scale_x_continuous("Genotype probability cutoff", breaks = data$GP ) +
       theme(axis.text=element_text(size=18),axis.title=element_text(size=20,face="bold"), plot.title = element_text(size=25, face="bold", hjust = 0.5))
}

ggsave(pdfout, plot=p, device="pdf")

