library("genetics")

options <- commandArgs(trailingOnly=T)
file <- options[1]
data <- read.table(file, header=F, na="NA")
ctgs <- data$V1
un_ctgs <- unique(ctgs)
counter=0;
for (uc in un_ctgs)
{
  counter = counter+1
  print(paste(counter, uc, sep="  "))
  sub_data <- subset(data, V1==uc)
  ctg=sub_data[1, 1]
  sub_snps <- sub_data$V2
  if(length(sub_snps) > 1){
    sub_data <- sub_data[,c(-1,-2)]
    sub_data <- apply(sub_data, 1:2, function(x){if(! is.na(x)){return(paste(x, x, sep="/"))}else{return(NA)} })
    df <- as.data.frame(t(sub_data))
    colnames(df) <- paste("SNP", 1:length(sub_snps), sep="")
    for(i in colnames(df)){df[,i] <- genotype(df[,i])}
    ld <- LD(df)
    r2<-(ld$r)^2
    rownames(r2) <- sub_snps
    colnames(r2) <- sub_snps
    out=paste("./tmp/", uc, "_r2.out",sep="")
    write.csv(r2, out)
  }
}
