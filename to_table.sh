perl -ne 'chomp; @t=split /\t+/,$_; $n++; if($n==1){print "<table class=\"table table-striped\">\n", "<thead><tr><th>No.</th> "; @arr=map{"<th>" . $_ . "</th>" }@t; print join(" ", @arr), " ", "</tr></thead> "; next}  $m++;  @arr=map{"<td>".$_. "</td>"}@t; print "<tr> ", join(" ", "<td>".$m."</td>", @arr), " ", "</tr> "; END{print "\n</table>\n"}' $1 