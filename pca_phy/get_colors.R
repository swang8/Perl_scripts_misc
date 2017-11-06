cl = colors()
cl = cl[c(10:150, 370:600)]
write.csv(file="colors.csv", cl, row.names = F)
