
ldhat_file = "/home/kjordan/Seq_Cap_analysis/new_analysis_2_14/ldhat_w2000_s1000_v2.out_normalized_3bls_min10k_masked"
rho_file = "/home/kjordan/Seq_Cap_analysis/new_analysis_2_14/rho.out_addNumSNP_20_ordered_for_Plot"
#phs_file = "all_ABD_genome_phs.txt_top2.5percent_rmDup2"
#phs_file = "all_chr_combined_phs.txt"
scale_file = "/home/kjordan/Seq_Cap_analysis/new_analysis_2_14/scale_file"


ldhat <- read.table(ldhat_file, header=T)
ldhat_win <- read.table(ldhat_file, header=T)
ldhat_winA <- subset(ldhat_win, grepl("a", Chr))
winA_D_quan <- quantile(ldhat_winA$tajimaD, c(0.025,0.975))
winA_Pi_quan <- quantile(ldhat_winA$Norm_pi, c(0.025,0.975))
ldhat_winB <- subset(ldhat_win, grepl("b", Chr))
winB_D_quan <- quantile(ldhat_winB$tajimaD, c(0.025,0.975))
winB_Pi_quan <- quantile(ldhat_winB$Norm_pi, c(0.025,0.975))
ldhat_winD <- subset(ldhat_win, grepl("d", Chr))
winD_D_quan <- quantile(ldhat_winD$tajimaD, c(0.025,0.975))
winD_Pi_quan <- quantile(ldhat_winD$Norm_pi, c(0.025,0.975))

## rescale chrosome size
## scale file:
## 1a  234 345
## 2a 345 567
scale_data <- read.table(scale_file, sep="\t", header=T);
scale_data$tot = scale_data$s+scale_data$l

for (i in 1:(length(ldhat$Chr))){
 chr = substr(ldhat[i,1], 1, 2)
 sub <- subset(ldhat, grepl(chr, Chr))
 max_len = max(sub$Start_Pos)
 total_len = scale_data[grepl(chr, scale_data$Chr), 4];
 ldhat[i, 2] = round(ldhat[i, 2] * (total_len / (max_len/1000000)) )
}
ldhat_win = ldhat

rho <- read.table(rho_file, header=T)
#phs <- read.table(phs_file, header=T)
rho_A_quan<- 7.47e-03
rho_B_quan<- 7.74e-03
rho_D_quan<- 9.73e-03
rho_0_quan <- 0.000000
#chrs <- unique(phs$Chr)
chrs=paste(rep(1:7, each=6), rep(c("a", "b", "d"), 14), rep(c(rep(c("s", "l"), each=3)),7), sep="" )
chrs_nosl <- paste(rep(1:7, each=3), c("a", "b", "d"), sep="")
###chrs <- chrs[grep("4", chrs, invert=F)]
max_pi = numeric(0)
max_td = numeric(0)
min_td = numeric(0)

for (i in chrs_nosl){
  ldhat_subset2 <- subset(ldhat, grepl(i, Chr))
  max_pi = c(max_pi, max(ldhat_subset2$Norm_pi))
  max_td = c(max_td, max(ldhat_subset2$tajimaD))
  min_td = c(min_td, min(ldhat_subset2$tajimaD))
  ##break;
}
max_pi
max_td
min_td

for (n in 1:7){
  #pdffile = paste("chr_", n, "_poly.pdf", sep="")
  #pdf(pdffile)
  layout(matrix(c(1:6, 0, 7:12, 0), 7, 2, byrow = FALSE), heights=c(1,0.5,1,0.5,1,0.5,0.2), widths=c(1,1.3))
  par(mar=c(0,4.1,1,1))
  for (sl in c("s", "l"))
  { 
    
    for (abd in c("a", "b", "d"))
    {
      chr = paste(n, abd, sl, sep="")
      if(chr == "4as") chr="4al"
      else if (chr == "4al") chr = "4as"
      ldhat_subset <- subset(ldhat, grepl(chr, Chr))
      ldhat_win_subset <- subset(ldhat_win, grepl(chr, Chr))
      rho_subset <- subset(rho, grepl(chr, contig))
      print(paste("subset done", chr))
      xmax=max(ldhat_subset$Start_Pos)
      print(paste("xmax", xmax))
      xmin=min(ldhat_subset$Start_Pos)
      print(paste("xmin", xmin))
    #  if(grepl("4a", chr)){
    #    len=length(ldhat_subset$Start_pos)
    #    v=numeric(len)
    #    v[1] = ldhat_subset$Start_pos[len]
    #    for(i in 2:len){
    #      v[i] = v[i-1] + ldhat_subset$Start_pos[i-1] - ldhat_subset$Start_pos[i]
    #    }
    #    ldhat_subset$Start_pos = v
    #  }
      #ldhat_subset$Norm_Pi = ldhat_subset$Norm_Pi[order(ldhat_subset$Start_Pos)]
      #ldhat_subset$Start_Pos[order(ldhat_subset$Start_Pos)]
      chr_sub = substr(chr, 1,2)
      limy_pi = max_pi[which(chrs_nosl == chr_sub)]
      print(paste("limy_pi", limy_pi))
      
      #
      cc = gsub("a",".",chr)
      cc = gsub("b",".",cc)
      cc = gsub("d",".",cc)
      
      max_x = max(ldhat$Start_Pos[grepl(cc, ldhat$Chr)], na.rm=T)
      min_x = min(ldhat$Start_Pos[grepl(cc, ldhat$Chr)], na.rm=T)
      
      plot(ldhat_subset$Start_Pos, ldhat_subset$Norm_pi, xlab="", axes=F, ylab="Pi", type="l", col="white", ylim=c(0, limy_pi), xlim=c(min_x, max_x))
      polygon(c(ldhat_subset$Start_Pos, rev(ldhat_subset$Start_Pos)), c(ldhat_subset$Norm_pi, rep(0, length(ldhat_subset$Norm_pi))), col="skyblue2",border=NA)
      print("done ldhat")
      box()
      axis(2)
      quan <- numeric(2);
      if(grepl("a", chr)){quan=winA_Pi_quan}else if(grepl("b", chr)){quan=winB_Pi_quan}else{quan=winD_Pi_quan}
      pi_2.5per <- subset(ldhat_win_subset, Norm_pi < quan[1])
      pi_97.5per <- subset(ldhat_win_subset, Norm_pi > quan[2])
      rug(pi_2.5per$Start_Pos, col="red", lwd=3, ticksize =0.0115)
      rug(pi_97.5per$Start_Pos, col="navy", lwd=3, ticksize = 0.0115)
        
      #if (length(pi_1per$Norm_Pi) >= 1)
      #{
        #pi_min = min(ldhat_subset$normalized_Pi)
       # pi_max = max(ldhat_subset$normalized_Pi)
       # for(i in 1:length(pi_1per$Norm_Pi)){
        #  rect(pi_1per$Start_pos[i], pi_min, pi_1per$End_pos[i], pi_max, col="red", border=T)
        #}   
      #}
    
      #par(new=TRUE)
      
      
      #plot(rho_subset$Start_Pos, rho_subset$Rho, xlab="", axes=F, type="h", ylim=c(0, 0.005), xlim=c(xmin, xmax))
      print("done Rho")
      #box()
      #axis(4)
      #axis(1)
      if(grepl("a", chr)){quan=rho_A_quan}else if(grepl("b", chr)){quan=rho_B_quan}else{quan=rho_D_quan}
      #if(grepl("a", chr)){quanz=rho_0_quan}else if(grepl("b", chr)){quanz=rho_0_quan}else{quanz=rho_0_quan}
      rho_97.5per <- subset(rho_subset, Rho > quan[1])
      #rug(rho_97.5per$Start_Pos, col="hotpink", lwd=4, side=3)
      points(rho_97.5per$Start_Pos, rep(limy_pi, length(rho_97.5per$Start_Pos)), pch=4, col="black")
      
      limy_min_td = min_td[which(chrs_nosl == chr_sub)]
      limy_max_td = max_td[which(chrs_nosl == chr_sub)]
      plot(ldhat_subset$Start_Pos, ldhat_subset$tajimaD, xlab="", axes=F, ylab="D", type="l", col="white", ylim=c(limy_min_td, limy_max_td), xlim=c(min_x, max_x))
      polygon(c(ldhat_subset$Start_Pos, rev(ldhat_subset$Start_Pos)), c(ldhat_subset$tajimaD, rep(0, length(ldhat_subset$tajimaD))), col="wheat4",border=NA)
      print("done tajimaD")
      box()
      axis(2)
      #axis(1)
      quan <- numeric(2);
      if(grepl("a", chr)){quan=winA_D_quan}else if(grepl("b", chr)){quan=winB_D_quan}else{quan=winD_D_quan}
      td_2.5per <- subset(ldhat_win_subset, tajimaD < quan[1])
      td_97.5per <- subset(ldhat_win_subset, tajimaD > quan[2])
      rug(td_2.5per$Start_Pos, col="red", lwd=2.75)
      rug(td_97.5per$Start_Pos, col="navy", lwd=2.75)
    }
    axis(1)
    
  }
  Sys.sleep(4)
  dev.off()
}

save.image(file="plot.Rdata")