library("optparse")
 
option_list = list(
  make_option(c("-i", "--input"), type="character", default=NULL, 
              help="dataset file name", metavar="character"),
  make_option(c("-e", "--header"), type="integer", default=0,
              help="contains header or not", metavar="character"),
  make_option(c("-x", "--xlab"), type="character", default=NULL,
              help="the labele for X axis", metavar="character"),
  make_option(c("-y", "--ylab"), type="character", default=NULL,
              help="the label for Y axis", metavar="character"),
  make_option(c("-t", "--title"), type="character", default=NULL,
              help="the label for Title", metavar="character"),
  make_option(c("-s", "--subtitle"), type="character", default="",
              help="the label for subtitle", metavar="character")
); 
 
opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$input)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

data = read.table(opt$input, header=(opt$header==1) )
print(head(data))

library(ggplot2)

col = colnames(data)
print(col[1])

p = ggplot(data) + geom_histogram(aes(x=array(data[, col[1]])))

if (! is.null(opt$title))  p = p + ggtitle(opt$title)
if (! is.null(opt$subtitle))  p = p + labs(subtitle=opt$subtitle)
if (! is.null(opt$xlab) )  p = p + xlab(opt$xlab)
if (! is.null(opt$ylab))  p = p + ylab(opt$ylab)

p = p + 
theme(
    plot.title = element_text(size=30, face="bold", hjust=0.5),
    plot.subtitle=element_text(size=20, hjust=0.5, face="italic"),
    axis.title.x = element_text(size=20, face="bold"),
    axis.title.y = element_text(size=20, face="bold")
    ) + 
scale_x_continuous(limits=c(-0.1, 1))

pdfout = paste(opt$input, "pdf", sep=".")

ggsave(pdfout, plot=p, device="pdf")
