
####
abd <- read.table("/home/DNA/Data_analysis/SNP_discovery_in_Illuminar_data/new_bowtie_run/seven_acc_only/unique/gene_silencing_alo
ng_chromosome/A_B_D_silenced_genes", header=F)
  
abd_1_p <- abd$V4[abd$V2==1]
abd_2_p <- abd$V4[abd$V2==2]
abd_3_p <- abd$V4[abd$V2==3]
abd_4_p <- abd$V4[abd$V2==4]
abd_5_p <- abd$V4[abd$V2==5]
abd_6_p <- abd$V4[abd$V2==6]
abd_7_p <- abd$V4[abd$V2==7]

abd_1_s <- abd$V5[abd$V2==1]
abd_2_s <- abd$V5[abd$V2==2]
abd_3_s <- abd$V5[abd$V2==3]
abd_4_s <- abd$V5[abd$V2==4]
abd_5_s <- abd$V5[abd$V2==5]
abd_6_s <- abd$V5[abd$V2==6]
abd_7_s <- abd$V5[abd$V2==7]

par(mfrow=c(7,1))
sliding_window <- function(vec1, vec2, window_size, step_size, xlab, ylab)
{
  vec1 <- sort(vec1)
  vec2 <- vec2[order(vec1)]  
  vmax = max(vec1)
  vmin = min(vec1)
  # v1 , v2 for return
  start = vmin
  v1 = numeric();
  v2 = numeric();
  v3 = numeric();
  while(start <= (vmax - window_size))
  {
    v1 = c(v1, start)
    end = start + window_size
    win_count = 0
    win_count = sum(vec2[vec1 >= start & vec1 <=end])
    total_genes = length(vec2[vec1 >= start & vec1 <=end])
    if (total_genes == 0){
      v2 = c(v2, 0)
    }
    else{
      v2 = c(v2, win_count/total_genes)
    }
    
    v3 = c(v3, total_genes)
    
    start = start + step_size
  }
  #print(length(v1))
  #print(length(v2))
  #print(length(v3))
  min_num_genes_in_window = 10;
  plot(v1[v3>=min_num_genes_in_window], v2[v3>=min_num_genes_in_window], type="l", lwd=1.5, col="red", xlab="", ylab=ylab, xlim=c(0, 6.5e8), ylim=c(0, 0.9))
  title(xlab=xlab, cex.lab=1.5)
  par(new=T)
  plot(v1[v3>=min_num_genes_in_window], v3[v3>=min_num_genes_in_window], type="l", lwd=1.5, col="#0000FF7D", xaxt="n",yaxt="n",xlab="",ylab="", xlim=c(0, 6.5e8))
  axis(4)
  mtext("#Genes",side=4,line=3, cex=0.65)

}

sliding_window(abd_1_p, abd_1_s, 4000000, 1000000, "Chromosome 1", "Proportion")
sliding_window(abd_2_p, abd_2_s, 4000000, 1000000, "Chromosome 2", "Proportion")
sliding_window(abd_3_p, abd_3_s, 4000000, 1000000, "Chromosome 3", "Proportion")
sliding_window(abd_4_p, abd_4_s, 4000000, 1000000, "Chromosome 4", "Proportion")
sliding_window(abd_5_p, abd_5_s, 4000000, 1000000, "Chromosome 5", "Proportion")
sliding_window(abd_6_p, abd_6_s, 4000000, 1000000, "Chromosome 6", "Proportion")
sliding_window(abd_7_p, abd_7_s, 4000000, 1000000, "Chromosome 7", "Proportion")

####


plot_ld <- function(vec1, vec2)
{
  vec1 <- round(vec1, digits=1)
  #vec2 <- round(vec2, digits=1)
  dist <- seq(0, max(vec1), by=0.1)
  mean_vec = numeric(0)
  mean50_up_vec = numeric(0)
  mean50_down_vec = numeric(0)
  mean90_up_vec = numeric(0)
  mean90_down_vec = numeric(0)
  for (dist_i in dist)
  {
    vec = vec2[vec1>=dist_i-2.5 & vec1<=dist_i+2.5]
    #vec = vec2[vec1 == dist_i]
    mean_i = median(vec)
    mean_vec = c(mean_vec, mean_i)
    quan <- quantile(vec, c(0.25, 0.75, 0.05, 0.95))
    mean50_up_vec = c(mean50_up_vec, quan[2])
    mean50_down_vec = c(mean50_down_vec, quan[1])
    mean90_up_vec = c(mean90_up_vec, quan[4])
    mean90_down_vec = c(mean90_down_vec, quan[3])
  }
  plot(dist, mean_vec, xlab="Genetic distance (cM)", type="n", ylab=expression(r^2), ylim=c(0,1))
  #lines(dist, mean90_up_vec, lty=1, col="blue", lwd=2)
  polygon(c(dist,rev(dist)), c(mean90_up_vec, rev(mean90_down_vec)), col="slateblue", border=NA)
  polygon(c(dist,rev(dist)), c(mean50_up_vec, rev(mean50_down_vec)), col="grey", border = NA)
  lines(dist, mean_vec, lwd=3,col="red")
  #lines(loess.smooth(dist, mean_vec, span = 0.3), lwd=3, col="red")
}



# Calculate posterior probability
Pr = numeric(0)
logit_p_ids = colnames(result$logit_p)
logit_e_ids = colnames(result$logit_e)
logitpi0 = result$mcmc$logitPi0
logF = result$mcmc$logF
logG = result$mcmc$logG
logH = result$mcmc$logH

for (i in 1:length(logit_p_ids))
{
  p_id = logit_p_ids[i]
  e_id = logit_e_ids[i]
  p_vec = result$logit_p[, p_id]
  e_vec = result$logit_e[, e_id]
  tmp = numeric(0)
  start  = length(p_vec) * 0.4;
  for (j in start:length(p_vec))
  {
    p = inv.logit(p_vec[j])
    e = inv.logit(e_vec[j])
    Pi0 = inv.logit(logitpi0[j])
    fv = exp(logF[j])
    gv = exp(logG[j])
    hv = exp(logH[j])
    
    p = dbeta(p, fv, gv) * dbeta(e, 1, hv) * (1 - Pi0)/(dbeta(p, fv, gv) * dbeta(e, 1, hv)*(1-Pi0) + dbeta(p, result$a.hat, result$a.hat)*dbeta(e, 1, result$d.hat)*Pi0)
    tmp = c(tmp, p)
  }
  Pr[i] = mean(tmp) 
}

# 
result <- read.mcmc()
n.iter <- result$n.iter/result$thin
burnin <- 0.1*n.iter
a.hat <- median(exp(result$mcmc$logA[burnin:n.iter]))
d.hat <- median(exp(result$mcmc$logD[burnin:n.iter]))
write.csv(data.frame("a.hat"=a.hat, "d.hat"=d.hat), file="", row.names=F)

# plot cultivar and landrace LD
cultivar_ld <- read.table("/home/swang/9K_genotyping/LD/cultivar_all_chr_ld.out_addDist", header=F)
landrace_ld <- read.table("/home/swang/9K_genotyping/LD/landraces_all_chr_ld.out_addDist", header=F)
cult_dist <- cultivar_ld$V1
cult_r2 <- cultivar_ld$V2
land_dist <- landrace_ld$V1
land_r2 <- landrace_ld$V2

# boxplot start
ld_boxplot <- function(cult_dist, cult_r2, land_dist, land_r2, ylim){
ds_cutoff = 50
cult_dist_cut <- cult_dist[cult_dist<=ds_cutoff]
cult_r2_cut <- cult_r2[cult_dist<=ds_cutoff]
cult_dist_range1 = cult_dist_cut[cult_r2_cut>=0 &cult_r2_cut<=0.25]
cult_dist_range2 = cult_dist_cut[cult_r2_cut>0.25 & cult_r2_cut<=0.5]
cult_dist_range3 = cult_dist_cut[cult_r2_cut>0.5 & cult_r2_cut<=0.75]
cult_dist_range4 = cult_dist_cut[cult_r2_cut>0.75 & cult_r2_cut<=1]

land_dist_cut <- land_dist[land_dist<=ds_cutoff]
land_r2_cut <- land_r2[land_dist<=ds_cutoff]
land_dist_range1 = land_dist_cut[land_r2_cut>=0 & land_r2_cut<=0.25]
land_dist_range2 = land_dist_cut[land_r2_cut>0.25 & land_r2_cut<=0.5]
land_dist_range3 = land_dist_cut[land_r2_cut>0.5 & land_r2_cut<=0.75]
land_dist_range4 = land_dist_cut[land_r2_cut>0.75 & land_r2_cut<=1]

col_cult = "white"
col_land = "grey"
par(mar=c(4.5,4.5,1,1))
plot(1, type="n", axes=F, xlim=c(0,1), frame.plot=T, lwd=3, cex.lab=2, ylim=c(0,ylim), xlab=expression(italic(r)^2),ylab="Genetic distance (cM)")
box(lwd=3)
axis(1, lwd=1, lwd.ticks=1, cex.axis=1.5, at=seq(0.25/2,1-0.25/2,by=0.25),labels=c("0-0.25", "0.25-0.5","0.5-0.75","0.75-1"))
axis(2, lwd=1, cex.axis=1.5)
abline(v=seq(0,1,by=0.25), lty=3,lwd=2,col="gray60")
boxplot(cult_dist_range1, add=T, at=c(0.25/3),boxwex=0.1,col=col_cult, axes=F, outcex=0.5,outpch=".", outline=T)
boxplot(cult_dist_range2, add=T, at=c(0.25+0.25/3),boxwex=0.1,col=col_cult, axes=F, outcex=0.5,outpch=".", outline=T)
boxplot(cult_dist_range3, add=T, at=c(0.5+0.25/3),boxwex=0.1,col=col_cult, axes=F, outcex=0.5,outpch=".", outline=T)
boxplot(cult_dist_range4, add=T, at=c(0.75+0.25/3),boxwex=0.1,col=col_cult, axes=F,outcex=0.5,outpch=".", outline=T)
#boxplot(c(cult_dist_range1,cult_dist_range2), add=T, at=c(0+0.5/3),boxwex=0.1,col=col_cult)
#boxplot(c(cult_dist_range3,cult_dist_range4), add=T, at=c(0.5+0.5/3),boxwex=0.1,col=col_cult)
boxplot(land_dist_range1, add=T, at=c(0.5/3),boxwex=0.1,col=col_land, axes=F, outcex=0.5,outpch=".", outline=T)
boxplot(land_dist_range2, add=T, at=c(0.25+0.5/3),boxwex=0.1,col=col_land, axes=F, outcex=0.5,outpch=".", outline=T)
boxplot(land_dist_range3, add=T, at=c(0.5+0.5/3),boxwex=0.1,col=col_land, axes=F, outcex=0.5,outpch=".",outline=T)
boxplot(land_dist_range4, add=T, at=c(0.75+0.5/3),boxwex=0.1,col=col_land, axes=F, outline=T, outpch=".")
#boxplot(c(land_dist_range1,land_dist_range2), add=T, at=c(0+1/3),boxwex=0.1,col=col_land)
#boxplot(c(land_dist_range3,land_dist_range4), add=T, at=c(0.5+1/3),boxwex=0.1,col=col_land)

# wilcox test
rang_test1 <- wilcox.test(cult_dist_range1, land_dist_range1, alternative="g")
rang_test2 <- wilcox.test(cult_dist_range2, land_dist_range2, alternative="g")
rang_test3 <- wilcox.test(cult_dist_range3, land_dist_range3, alternative="g")
rang_test4 <- wilcox.test(cult_dist_range4, land_dist_range4, alternative="g")
print(c(rang_test1$p.value, rang_test2$p.value, rang_test3$p.value, rang_test4$p.value))

print(summary(cult_dist_range1))
print(summary(cult_dist_range2))
print(summary(cult_dist_range3))
print(summary(cult_dist_range4))
print(summary(land_dist_range1))
print(summary(land_dist_range2))
print(summary(land_dist_range3))
print(summary(land_dist_range4))
}
# call ld_boxplot
ld_boxplot(cult_dist, cult_r2, land_dist, land_r2, 50)

# boxplot for neighbor SNPs
data <- read.table('/home/DNA/Data_analysis/9K_data_analysis/cultivar_landraces_neighboring_SNP_LD.out', header=T)
ld_boxplot (data$distance, data$cultivar_r2, data$distance, data$landrace_r2, 4)

# boxplot end


#density plot
ld_densityplot <- function(cult_dist, cult_r2, land_dist, land_r2){
ds_cutoff = 1
cult_dist_cut <- cult_dist[cult_dist<=ds_cutoff]
cult_r2_cut <- cult_r2[cult_dist<=ds_cutoff]
land_dist_cut <- land_dist[land_dist<=ds_cutoff]
land_r2_cut <- land_r2[land_dist<=ds_cutoff]

par(mfrow=c(3,1))
par(mar=c(4,4.2,1,1))
#plot(1, type="n", xlab="Genetic distance (cM)", ylab="Density", xlim=c(0,ds_cutoff), ylim=c(0,7))
step = 1/3
x<-seq(0,1,by=step)

colors=c(rgb(215, 25, 28, max=255), rgb(253, 174, 97, max=255),rgb(171, 221, 164, max=255),rgb(43, 131, 186, max=255))
for (i in 1:(length(x)-1))
{
  plot(1, type="n", xlab="Genetic distance (cM)", ylab="Density", xlim=c(0,ds_cutoff),ylim=c(0,12))
  cult_dist_range = cult_dist_cut[cult_r2_cut>=x[i] &cult_r2_cut<=x[i+1]]
  land_dist_range = land_dist_cut[land_r2_cut>=x[i] & land_r2_cut<=x[i+1]]
  lines(density(cult_dist_range), lty=1, lwd=3)
  lines(density(land_dist_range), lty=4, lwd=3)
}
}
# densityplot end

# LD loess plot
ld_loessplot <- function(cdist, cr2, ldist, lr2, cutoff){
ds_cutoff = cutoff
cult_dist_cut <- cdist[cdist<=ds_cutoff]
cult_r2_cut <- cr2[cdist<=ds_cutoff]
land_dist_cut <- ldist[ldist<=ds_cutoff]
land_r2_cut <- lr2[ldist<=ds_cutoff]

par(mfrow=c(3,1))
par(mar=c(4,4.2,1,1))
#plot(1, type="n", xlab="Genetic distance (cM)", ylab=expression(r^2), xlim=c(0,ds_cutoff), ylim=c(0,1))
step = 1/3
x<-seq(0,1,by=step)
print(x);
#colors=c(rgb(215, 25, 28, max=255), rgb(253, 174, 97, max=255),rgb(171, 221, 164, max=255),rgb(43, 131, 186, max=255))
for (i in 1:(length(x)-1))
{
  print(x[i])
  print(x[i+1])
  cult_dist_range = cult_dist_cut[cult_r2_cut>=x[i] & cult_r2_cut<=x[i+1]]
  cult_r2_range = cult_r2_cut[cult_r2_cut>=x[i] & cult_r2_cut<=x[i+1]]
  
  land_dist_range = land_dist_cut[land_r2_cut>=x[i] & land_r2_cut<=x[i+1]]
  land_r2_range = land_r2_cut[land_r2_cut>=x[i] & land_r2_cut<=x[i+1]]
  
  cult_order = order(cult_dist_range)
  land_order = order(land_dist_range)
  #plot(loess.smooth(cult_dist_range[cult_order], cult_r2_range[cult_order]), type="l", lty=1, lwd=3, col="blue", xlim=c(0,5), xlab="Genetic distance (CM)", ylab=expression(r^2))
  plot(1, type="n", xlim=c(0,5), ylim=c(x[i], x[i+1]), xlab="Genetic distance (CM)", ylab=expression(r^2))
  points(cult_dist_range[cult_order], cult_r2_range[cult_order], cex=0.2, col="blue")  
  points(land_dist_range[land_order], land_r2_range[land_order], cex=0.2, col="red")
  lines(loess.smooth(cult_dist_range[cult_order], cult_r2_range[cult_order]),lty=1, lwd=3, col="blue")
  lines(loess.smooth(land_dist_range[land_order], land_r2_range[land_order]), lty=4, lwd=3, col="red")
  print(summary(land_r2_range))
}
}
# loess end


sliding_ld <- function(dist, r2){
  st = 0.5
  ws = 1
  x <- seq(0, max(dist), by=st)
  y = numeric(0)
  for (i in x){
    #print(i)
    m <- mean(r2[dist>=i-ws/2 & dist<=i+ws/2])
    y <- c(y, m)
  }
  r <- data.frame("dist"=x, "r2"=y)
  return(r)
}
dist_cutoff = 25
cult_r2_sub = cult_r2[cult_dist<=dist_cutoff]
cult_dist_sub = cult_dist[cult_dist<=dist_cutoff]
land_r2_sub = land_r2[land_dist<=dist_cutoff]
land_dist_sub = land_dist[land_dist<=dist_cutoff]

par(mfrow=c(1,1))
step = 1/3
plot(1, xlim=c(0,dist_cutoff), ylim=c(0,1),type="n", xlab="Pairwise distance, cM", ylab=bquote(paste("LD, ", italic(r^2))))
for (i in seq(0,1-step,by=step)){
  cult_dist_range = cult_dist_sub[cult_r2_sub>i & cult_r2_sub<=(i+step)]
  cult_r2_range = cult_r2_sub[cult_r2_sub>i & cult_r2_sub<=(i+step)]  
  #lines(loess.smooth(cult_dist_range, cult_r2_range), lwd=3, col="red");
  cult_sld <- sliding_ld(cult_dist_range, cult_r2_range)
  #lines(loess.smooth(cult_sld$dist, cult_sld$r2), lwd=3, col="red");
  lines(cult_sld$dist, cult_sld$r2, lwd=3, col="red");
  
  land_dist_range = land_dist_sub[land_r2_sub>i & land_r2_sub<=(i+step)]
  land_r2_range = land_r2_sub[land_r2_sub>i & land_r2_sub<=(i+step)]
  #lines(loess.smooth(land_dist_range=, land_r2_range), lwd=3, col="blue");
  r2_sld <- sliding_ld(land_dist_range, land_r2_range)
  #lines(loess.smooth(r2_sld$dist, r2_sld$r2), lwd=3, col="blue");
  lines(r2_sld$dist, r2_sld$r2, lwd=3, col="blue");
}
for (i in seq(0,1,by=step)){
  abline(h=i, lty=2)  
}
legend(15,0.995, legend=c("Cultivar", "Landrace"), pch=c("-","-"),pt.cex=1.5, pt.lwd=3, col=c("red", "blue"), bty="n")

plot(1, xlim=c(0,1),ylim=c(0,1), xlab=bquote(paste("LD, ", italic(r^2))), ylab="Proportion", type="n",axes=F)
step=0.5;
for(i in seq(0,1,by=step)){abline(v=i, lty=2)}
axis(1,at=seq(0,1,by=step));axis(2)
for (i in seq(0,1-step,by=step)){
  cult_r2_range = cult_r2_sub[cult_r2_sub>=i & cult_r2_sub<=(i+step)]
  t1_len=length(cult_r2_range)
  land_r2_range = land_r2_sub[land_r2_sub>=i & land_r2_sub<=(i+step)]
  t2_len=length(land_r2_range)
  range <- seq(i, i+step, by = 0.01)
  y1 <- numeric(0);
  y2 <- numeric(0);
  for (j in range){
    sub_len1 = length(cult_r2_range[cult_r2_range<=j])
    y1 <- c(y1, sub_len1/t1_len)
    sub_len2 = length(land_r2_range[land_r2_range<=j])
    y2 <- c(y2, sub_len2/t2_len)
  }
  lines(range, y1, lwd=3, col="blue")
  lines(range, y2, lwd=3, col="red")
}




boxplot(list("0.01"=phs$V2[phs$V1==0.01], "0.02"=phs$V2[phs$V1==0.02],"0.03"=phs$V2[phs$V1==0.03], "0.04"=phs$V2[phs$V1==0.04], "0.05"=phs$V2[phs$V1==0.05], "0.06"=phs$V2[phs$V1==0.06],"0.07"=phs$V2[phs$V1==0.07],"0.08"=phs$V2[phs$V1==0.08],"0.09"=phs$V2[phs$V1==0.09],"0.10"=phs$V2[phs$V1==0.10]), col="red")


par(mar=c(4.1,4.1,1,1))
barplot(t(as.matrix(ratio_df)), beside=T,col=fill_col, axes=F,xlab="Ratio", ylab="Density", cex.lab=1.5)
axis(1,seq(0,60,by=12),labels=c(0,0.2,0.4,0.6,0.8,1.0), cex.axis=1.5)
axis(2, cex.axis=1.5)
legend(31,2.7, legend=c("Before filtering", "After filtering"),fill=fill_col,bty="n",y.intersp=1.5, cex=1.5)


d <- read.table('/home/DNA/Wheat_exom_capture_reference/blastn.summary.out_homeologs_filtered_addCoverage', header=F)
d <- d[,5:7]
colnames(d) <- c("A", "B", "D")
ab <- d$A[d$B>0]/d$B[d$B>0]
ad <- d$A[d$D>0]/d$D[d$D>0]
bd <- d$B[d$D>0]/d$D[d$D>0]
dev.off()
par(mfrow=c(3,1))
hist(log2(ab), breaks=100, xlim=c(-5, 5), xlab="log2(A/B)", main=NULL, col="slateblue")
hist(log2(ad), breaks=200, xlim=c(-5, 5), xlab="log2(A/D)", main=NULL, col="slateblue")
hist(log2(bd), breaks=200, xlim=c(-5, 5), xlab="log2(B/D)", main=NULL, col="slateblue")
