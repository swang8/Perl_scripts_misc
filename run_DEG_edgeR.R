library(edgeR)

args = commandArgs(trailingOnly=TRUE)
file = args[1]
#file="counts_all_formatted.txt"
count_data = read.table(file, header=T, sep="\t")

row.names(count_data) = count_data[,1]
count_data = count_data[, 7:ncol(count_data)]

samples = colnames(count_data)

# One bad sample
# bad_sample=c("Ch48_C_2")
# bad_sample_index = which(samples == bad_sample)
# 
# count_data = count_data[, -1 * bad_sample_index]

group = gsub("_\\d+$", "", colnames(count_data))

group = as.factor(group)

group_levels = levels(group)

# put all into DGElist
y = DGEList(count = count_data, group = group)
y <- calcNormFactors(y)
design <- model.matrix(~0+group)
y <- estimateDisp(y,design)
fit <- glmQLFit(y,design)

logcpm = cpm(y, log=TRUE)
write.csv(logcpm, file="logCPM.csv")

## plot MDS
# The function plotMDS draws a multi-dimensional scaling plot of the RNA samples in which distances correspond to leading log-fold-changes between each pair of RNA samples. The leading log-fold-change is the average (root-mean-square) of the largest absolute log-fold- changes between each pair of samples. This plot can be viewed as a type of unsupervised clustering. The function also provides the option of computing distances in terms of BCV between each pair of samples instead of leading logFC
pdf("mds.pdf")
plotMDS(y, col=rep(1:4, each=3))
dev.off()

## plot BCV
# The dispersion estimates can be viewed in a BCV plot.
pdf("BCV.pdf")
plotBCV(y)
dev.off()

## plot plotQLDisp(fit)
pdf("QLDisp.pdf")
plotQLDisp(fit)
dev.off()

## 


# perfrom quasi-likelihood F-tests
# edgeR offers many variants on analyses. The glm approach is more popular than the classic approach as it offers great flexibilities. 
# There are two testing methods under the glm framework: likelihood ratio test and quasi-likelihood F-test. 
# The quasi-likelihood method is highly recommended for differential expression analyses of bulk RNA-seq data as it gives stricter
# error rate control by accounting for the uncertainty in dispersion estimation.
# The likelihoodratio test can be useful in some special cases such as single cell RNA-seq and datasets with no replicates

##control = c(rep("Ch24_M", 3), "Ch4_M", "Ch8_M", "Sit24_M", "Ch0_M", "Ch24_M")
##test = c("Sit24_M", "Stg24_M", "Cmp24_M", "Sit4_M", "Sit8_M", "SCh48_M", "Ch24_M", "Ch48_M")

control = c("C", "J1", "J3", "J4")
test = control
print(test)
comps = character(length(control))

for (i in 1:(length(control)-1)){
  for (j in (i+1):length(control)){
    print(paste(i, j, sep=" - "))
    if (control[i] == test[j]){next}
    comp = paste(control[i], "VS", test[j], sep="_")
    comps[i] = comp
    print(comp)
    ##
    contrast = numeric(length(group_levels))
    contrast[which(group_levels == control[i])] = -1
    contrast[which(group_levels == test[j])] = 1

    ## perform the qlf test
    qlf = glmQLFTest(fit, contrast = contrast)

    ## plot MD
    pdf(paste(comp, "MD.pdf", sep=".") )
    plotMD(qlf)
    abline(h=c(-1, 1), col="blue")
    dev.off()

    #output 
    output = paste("QLF", comp, "csv", sep=".")
    tb  =  qlf$table
    tb$FDR = p.adjust(tb$PValue, "fdr")
    tb = tb[order(tb$PValue), ]
    write.csv(tb, file=output)

    ## perform the exact test
    et = exactTest(y, pair=c(control[i],test[j]))
    #output 
    output = paste("et", comp, "csv", sep=".")
    tb  =  et$table
    tb$FDR = p.adjust(tb$PValue, "fdr")
    tb = tb[order(tb$PValue), ]
    write.csv(tb, file=output)
  }  
}



