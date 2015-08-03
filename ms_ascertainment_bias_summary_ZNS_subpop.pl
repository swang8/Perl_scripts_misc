#!/usr/bin/perl -w

# Script to read ms program output 
# Generate ascertainment bias by selecting sites variable in a small discovery panel
# Generate summaries: % shared alleles; private alleles in pop 1 and pop2; fixed differences;
# Generate minor allele frequency spectrum
# usage: 

use Cwd;
$curr = cwd();
$file=$ARGV[0];

open (INFILE, "$curr/$file");
#open (OUT2, ">$curr/$out");
#open (OUT, ">$curr/MAF.txt");
#open (OUT1, ">$curr/testing.txt");
#print OUT2 "Num","\t","shared","\t","private1","\t","private2","\t","fixed","\n";

$i=0;
$k=0;

$pop1=134; # population size 1 - 134
$pop2=866; # population size 2 - 866

while(<INFILE>){	
	if(/^\/\/\t(.+)$/){
		$i++;
		#$par=$1;
		%ms=();
		$row = 0;
		while (1) {  # endless loop to get all of comment line
			my $next_line = <INFILE>;
			if ($next_line =~ /^[01]/){
				chomp $next_line;
				$row++;
				$arrlen='';
				@seqarr = split //, $next_line;
				$arrlen=@seqarr;
				#print OUT "length $arrlen: seq: @seqarr\n";
				$col=1;
				foreach $site(@seqarr){
					#print OUT1 "row $row\t";
					#print OUT1 "column $col\t";
					#print OUT1 "site $site\n";
					$ms{$row}{$col++}{'site'}=$site;
					#print OUT1 "  column $col\n";
					#print OUT1 "         site $site\n";
				}
					#print OUT1 "row $row\n";
					#print OUT1 " length $arrlen\n";
			}
			if ($next_line =~ /positions/) {
				chomp $next_line;
				@posarray = split /\s+/, $next_line;
				shift @posarray;
				#print OUT1 "posarray: @posarray","\n";
			}
				
			if ($next_line =~ /^$/ || eof(INFILE)) {
				$k=1;
				last;  # break out of loop

			}
		}
	if ($k==1){

		print "\n","//","\n","segsites:","\t","$arrlen","\n";
		print "positions:","\t";
		for ($tcol=1;$tcol<=$arrlen;$tcol++){				
				print "$posarray[$tcol-1]\t";
			}
		print "\n";	
		for ($trow=1;$trow<=$pop1;$trow++){
			#print OUT1 "row:  $trow\n";
			for ($tcol=1;$tcol<=$arrlen;$tcol++){				
					print "$ms{$trow}{$tcol}{'site'}";
				}
					print "\n";
			}
		
		
		print "\n","//","\n","segsites:","\t","$arrlen","\n";
		print "positions:","\t";
		for ($tcol=1;$tcol<=$arrlen;$tcol++){				
				print "$posarray[$tcol-1]\t";
			}
		print "\n";	
		for ($trow1=$pop1+1;$trow1<=$pop1+$pop2;$trow1++){
			#print OUT1 "row:  $trow1\n";
			for ($tcol=1;$tcol<=$arrlen;$tcol++){					
					print "$ms{$trow1}{$tcol}{'site'}";
				}
					print "\n";
			}
		$k=0;	
		}
	}
}
		
		
#####################################################################		

