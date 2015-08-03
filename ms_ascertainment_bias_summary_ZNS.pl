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
open (OUT1, ">$curr/testing.txt");
#print OUT2 "Num","\t","shared","\t","private1","\t","private2","\t","fixed","\n";

$i=0;
$k=0;
$p=0; ## if 1 then print allele frequencies for each site
$pop1=134; # population size 1 - 134
$pop2=866; # population size 2 - 866
#$asc_pop=3; # size of acsertainment panel
@asc=(1,2,3);
#for($ind=1;$ind<=$asc_pop;$ind++){push @asc,134+int(rand($pop1+$pop2))} # random number generator is used to select individuals to asc. panel
#@asc=(1,2); # individuals in the ascertainment panel; random number generator can be used to select individuals

#@asc=(1,2,4,5,6,7,8,9,10,$pop1+1,$pop1+2); # individuals in the ascertainment panel; 
		#print "ms 10 2 -t 5","\n"; 
		#print "30563 49966 13894","\n";

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
##################### ascertainment bias  #########################
# select sites that are polymorphic in the ascertainment panel chosen from first $asc individuals
	if ($k==1){
		@var_pos=();
		for ($tcol=1;$tcol<=$arrlen;$tcol++){
			$j=$f=0;
			#print OUT1 "col: $tcol\n";
			#for ($trow=1;$trow<=$asc;$trow++){
			foreach $trow(@asc){
					if($ms{$trow}{$tcol}{'site'}==0){$j++;}
					if($ms{$trow}{$tcol}{'site'}==1){$f++;}
				}
				if($j>0 && $f>0){push @var_pos,$tcol;} # save positions of polymorphic sites in array
			}
		#print OUT1 "polymorph_pos: @var_pos","\n";
		$k=2;
		$new_arrlen=@var_pos;
		
		print "\n","//","\n","segsites:","\t","$new_arrlen","\n";
		print "positions:","\t";
		foreach $tcol(@var_pos){ # use positions ascertained in the discovery panel				
				print "$posarray[$tcol-1]\t";
			}
		print "\n";	
		for ($trow=1;$trow<=$pop1;$trow++){
			#print OUT1 "row:  $trow\n";
			foreach $tcol(@var_pos){ # use positions ascertained in the discovery panel				
					print "$ms{$trow}{$tcol}{'site'}";
				}
					print "\n";
			}
		
		
		print "\n","//","\n","segsites:","\t","$new_arrlen","\n";
		print "positions:","\t";
		foreach $tcol(@var_pos){ # use positions ascertained in the discovery panel				
				print "$posarray[$tcol-1]\t";
			}
		print "\n";	
		for ($trow1=$pop1+1;$trow1<=$pop1+$pop2;$trow1++){
			print OUT1 "row:  $trow1\n";
			foreach $tcol(@var_pos){ # use positions ascertained in the discovery panel				
					print "$ms{$trow1}{$tcol}{'site'}";
				}
					print "\n";
			}
		$k=0;	
		}
		
		
#####################################################################		
					
################### calculate proportion of shared, private and fixed mutations and MAF in two populations #########
	if ($k==10){
		#print OUT1 "		arrlength2: $arrlen\n";
		$shared=$pr1=$pr2=$fix=0;
		@pop1fr=();
		@pop2fr=();
		foreach $tcol(@var_pos){ # use positions ascertained in the discovery panel
			$a=$b=$c=$d=$maf1=$maf2=0;
			#print OUT1 "col: $tcol\n";
			for ($trow=1;$trow<=$pop1+$pop2;$trow++){
				#print OUT1 "row:  $trow\n";
				if($trow<=$pop1){
					#print OUT1 "site1: $ms{$trow}{$tcol}{'site'}\n";
					if($ms{$trow}{$tcol}{'site'}==0){$a++;}
					if($ms{$trow}{$tcol}{'site'}==1){$b++;}
				}
				if($trow>$pop1){
					#print OUT1 "site2: $ms{$trow}{$tcol}{'site'}\n";
					if($ms{$trow}{$tcol}{'site'}==0){$c++;}
					if($ms{$trow}{$tcol}{'site'}==1){$d++;}
				}	
			}
			#print OUT1 "abcd:$tcol\t$a\t$b\t$c\t$d\n";
			if($a>0 && $b>0 && $c>0 && $d>0){$shared++;
				if($a>$b){$maf1=$b/$pop1;}
				if($a<$b){$maf1=$a/$pop1;}
				if($c>$d){$maf2=$d/$pop2;}
				if($c<$d){$maf2=$c/$pop2;}
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a>0 && $b>0 && $c==0 && $d>0){$pr1++;
				if($a>$b){$maf1=$b/$pop1;}
				if($a<$b){$maf1=$a/$pop1;}
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a>0 && $b>0 && $c>0 && $d==0){$pr1++;
				if($a>$b){$maf1=$b/$pop1;}
				if($a<$b){$maf1=$a/$pop1;}
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a>0 && $b==0 && $c>0 && $d>0){$pr2++;
				if($c>$d){$maf2=$d/$pop2;}
				if($c<$d){$maf2=$c/$pop2;}
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a==0 && $b>0 && $c>0 && $d>0){$pr2++;
				if($c>$d){$maf2=$d/$pop2;}
				if($c<$d){$maf2=$c/$pop2;}
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a==0 && $b>0 && $c>0 && $d==0){$fix++;
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
			if($a>0 && $b==0 && $c==0 && $d>0){$fix++;
				push @pop1fr,$maf1;
				push @pop2fr,$maf2;
				}
		}
		
		if($p==1){
			foreach $fr(@pop1fr){
				print OUT "$fr\n";
			}
		}
		$pr_sh=$shared/$new_arrlen;
		$pr_pr1=$pr1/$new_arrlen;
		$pr_pr2=$pr2/$new_arrlen;
		$pr_fx=$fix/$new_arrlen;
		print OUT2 "$par\t";
		print OUT2 "$pr_sh\t"; # fraction of shared polymorphisms
		print OUT2 "$pr_pr1\t";# fraction of private polymorphisms in pop1
		print OUT2 "$pr_pr2\t";# fraction of private polymorphisms in pop2
		print OUT2 "$pr_fx\n";# fraction of fixed polymorphisms
		$k=0;
	}
	}
}

