library(VennDiagram)

## draw.quintuple.venn(area1, area2, area3, area4, area5, n12, n13, n14, n15,
##   n23, n24, n25, n34, n35, n45, n123, n124, n125, n134,
##   n135, n145, n234, n235, n245, n345, n1234, n1235,
##   n1245, n1345, n2345, n12345, category = rep("", 5),
##   lwd = rep(2, 5), lty = rep("solid", 5), col =
##   rep("black", 5), fill = NULL, alpha = rep(0.5, 5),
##   label.col = rep("black", 31), cex = rep(1, 31),
##   fontface = rep("plain", 31), fontfamily = rep("serif",
##   31), cat.pos = c(0, 287.5, 215, 145, 70), cat.dist =
##   rep(0.2, 5), cat.col = rep("black", 5), cat.cex =
##   rep(1, 5), cat.fontface = rep("plain", 5),
##   cat.fontfamily = rep("serif", 5), cat.just =
##   rep(list(c(0.5, 0.5)), 5), rotation.degree = 0,
##   rotation.centre = c(0.5, 0.5), ind = TRUE, cex.prop =
##   NULL, print.mode = "raw", sigdigs = 3, direct.area =
##   FALSE, area.vector = 0, ...)

# input:  csv file with header
opts = commandArgs(trailingOnly = T)
#csv_file = opts[1]
csv_file="~/Downloads/R_table_three_pedigree_position.csv"
print(paste("input", csv_file, sep=": "))

dat = read.csv(csv_file)

# figure out the overlapping
overlap <- function (d) {
  names = colnames(d)
  count = 0
  for (i in 1:nrow(d) ){
    x = as.matrix(d[i, ])
    if (all(x == 1)){
      count = count + 1
    }
  }
  print(paste("count:", count))
  return(count)
}

## plot function
plot_venn <- function (d, ...) {
  ##grid.newpage()
  if (length(colnames(d)) == 1) {
    out <- draw.single.venn(overlap(d), ...)
  }
  if (length(colnames(d)) == 2) {
    out <- draw.pairwise.venn(overlap(d[1]), overlap(d[2]), overlap(d[ 1:2]), ...)
  }
  if (length(colnames(d)) == 3) {
    out <- draw.triple.venn(overlap(d[1]), overlap(d[2]), overlap(d[3]), overlap(d[ 1:2]),
                            overlap(d[ 2:3]), overlap(d[ c(1, 3)]), overlap(d), ...)
  }
  if (length(colnames(d)) == 4) {
    out <- draw.quad.venn(overlap(d[1]), overlap(d[2]), overlap(d[3]), overlap(d[4]),
                          overlap(d[ 1:2]), overlap(d[ c(1, 3)]), overlap(d[ c(1, 4)]), overlap(d[ 2:3]),
                          overlap(d[ c(2, 4)]), overlap(d[ 3:4]), overlap(d[ 1:3]), overlap(d[ c(1, 2, 4)]), overlap(d[ c(1, 3, 4)]), overlap(d[ 2:4]), overlap(d), ...)
  }
  if (length(colnames(d)) == 5) {
    out <- draw.quintuple.venn(overlap(d[1]), overlap(d[2]), overlap(d[3]), overlap(d[4]), overlap(d[5]),
                               overlap(d[ 1:2]), overlap(d[ c(1, 3)]), overlap(d[ c(1, 4)]), overlap(d[ c(1, 5)]),
                               overlap(d[ 2:3]), overlap(d[ c(2, 4)]), overlap(d[ c(2, 5)]),
                               overlap(d[ 3:4]), overlap(d[ c(3, 5)]), overlap(d[ c(4, 5)]),
                               overlap(d[ 1:3]), overlap(d[ c(1, 2, 4)]), overlap(d[ c(1, 2, 5)]), overlap(d[ c(1, 3, 4)]), overlap(d[ c(1, 3, 5)]),
                               overlap(d[ c(1, 4, 5)]), overlap(d[ 2:4]), overlap(d[ c(2, 3, 5)]), overlap(d[ c(2, 4, 5)]), overlap(d[ 3:5]),
                               overlap(d[ 1:4]), overlap(d[ c(1, 2, 3, 5)]), overlap(d[ c(1, 2, 4, 5)]), overlap(d[ c(1, 3:5)]), overlap(d[ 2:5]), overlap(d), ...)
  }
  if (!exists("out"))
    out <- "Errors!"
  return(out)   
}

## make plots
## pick the columns you want to plot
picked_cols = colnames(dat) # take all
#picked_cols = colnames(dat)[c(1,3,5)] # take three columns 1, 3, and 5

#pick colors
colors = palette(rainbow(length(picked_cols))) 

# run the plot
out = plot_venn(dat[picked_cols], category = toupper(picked_cols), lty = "blank", fill = colors, margin = 0.1)


