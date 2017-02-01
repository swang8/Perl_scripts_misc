# Pairwise Fst
data <- read.table("~/combined_for_fst_rmUKAC_addCanada.dat_rmNA", header=F, sep="\t", na.strings="NA", dec=".", strip.white=TRUE)  #load text file
data1 <- data[,-2]     #remove column with clone id (do not run this line on your own data, if you do not have this extra column)
library(Geneclust)           #load Geneclust
gtypes=data1[,2:ncol(data1)]  #index only genotype data
gtypes1=matrix(as.integer(as.matrix(gtypes)),nrow(gtypes),ncol(gtypes))       #neccessary data formating
gtypes2=FormatGenotypes(gtypes1)   #more data formatting
pop.mbrship=data1[,1]               #population membership for individuals
pop.mbrship=as.numeric(pop.mbrship)  #conver to numeric (I couldn't get the function to work properly without this step)
npopmax=length(unique(pop.mbrship))   #number of populations
fst=Fst(gtypes2$genotypes,gtypes2$allele.numbers,pop.mbrship,npopmax)   #providing necessary parameters for Fst calculation in Geneclust
fst=fst$Pairwise.Fst     #isolate pair-wise fst    (note: if you type "fst" before this line, you will also get  Fit and  Fis, which is useful)

popnames=unique(data1[,1])   #population names
FST=cbind(levels(popnames),fst)         #add population names
FST=rbind(c("",levels(popnames)),FST)    #add population names

write.table(FST,file="Pairwise_FST.txt",row.names=FALSE,col.names=FALSE,sep="\t",append=FALSE)  #write results to a file
