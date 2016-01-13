
data = read.table("http://129.130.90.211/share_files/kjordan/NAM_pop/transform_GBS/Paper/candidates/Individual_QTL_regions_w_trait.txt", header=T, sep="\t")
rbf = read.table("http://129.130.90.211/share_files/kjordan/NAM_pop/transform_GBS/Paper/rec_breakpoint.total_count.txt", header=T, sep="\t")
rbs = strsplit(as.character(rbf$Bin), ":", fixed=T)
c1 = character(length(s))
c2 = numeric(length(s))
for (i in 1:length(s)){
  c1[i] = rbs[[i]][1]
  c2[i] = rbs[[i]][2]
}
rbf["Chr"] = c1
rbf["Pos"] = c2



#Population      TraitName       Chr     Location_start  Loc_end
#NAM1    Median  5A      0       4.5
#NAM1    Total   2A      90.2    92.5
#NAM1    Total   2B      59.2    67.1

traits = unique(data$TraitName)
all_chrs = paste(rep(1:7, each=3), c("A", "B", "D"), sep="")
nam_pop = 1:30
xmax = 170

dev.off()
for (i in 1:7){
  print(paste("Chr: ", i))
  layout(matrix(1:6, ncol=1), heights=c(1, 0.5, 1,0.5,1,0.5))
  par(mar=c(3,3,0,0))
  chrs = all_chrs[grepl(i, all_chrs)]
  sub_data = subset(rbf, grepl(i, Chr))
  xmax = as.numeric(max(sub_data[, 4]))
  print(paste("Max: ", xmax))
  for (chr in chrs){
    # QTL plot
    qtl_data = subset(data, grepl(chr, Chr))
    num_rows = nrow(qtl_data)
    plot(1, type="n", xlim=c(0, xmax), ylim=c(0, 30), xlab="", ylab="NAM")
    if(num_rows != 0){ 
      for (row in 1:num_rows){
        color = "red"
        if(grepl("Median", qtl_data[row, 2])){color="blue"}
        nam_id = as.numeric(sub("NAM", "", qtl_data[row, 1]))
        rect(qtl_data[row, 4], nam_id-0.5, qtl_data[row, 5], nam_id+0.5, col=color)
      }
    }
    #abline(h=nam_pop, lty=3)
    ## rec freq
    freq_data = subset(rbf, grepl(chr, Chr))
    #if(num_rows != 0){
      plot(freq_data$Pos, freq_data$Total, type="h", xlim=c(0, xmax), ylim=c(0, 30), xlab="Position, cM", ylab="Count")
    #}
    #else{
     # plot(freq_data$Pos, freq_data$Total, type="n", xlim=c(0, xmax), ylim=c(0, 30), xlab="Position, cM", ylab="Count")
   # }
  }
  Sys.sleep(5)
  dev.off()
}


