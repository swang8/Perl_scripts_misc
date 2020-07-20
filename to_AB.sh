# convert hmp to AB based on parents
perl -ne '
BEGIN{$r=`wc -l $ARGV[0]`; $r+=0;  $is_homo = sub{$seq=shift; @pp=split //, $seq; return $pp[0] eq $pp[1]?1:0} }
chomp;
@t=split /\s+/,$_;
$n++;
if($n <= $r){$snp{$t[0]}=1}
else{
  $m++;
  if($m==1){
     map{
     ## input parent names here
     ## Parent 1
     if($t[$_] eq "TAM113" or $t[$_] eq "TAM113_2" ){push @arr1, $_} 

     ## Parent 2
     if($t[$_] eq "Gallagher" or $t[$_] eq "Gallagher_2"){push @arr2, $_} 

     }1..$#t;
     print $_, "\n"; next}
   #next unless exists $snp{$t[0]};
   @par1=@t[@arr1]; @par2=@t[@arr2];
   %h1=(); %h2=();
   map{$h1{$_}++ unless /N/}@par1; map{$h2{$_}++ unless /N/}@par2;
   $p1_gen="NN"; $p1_gen = (sort{$h1{$b} <=> $h1{$a}}keys %h1)[0] if (keys %h1) > 0;
   $p2_gen="NN"; $p2_gen = (sort{$h2{$b} <=> $h2{$a}}keys %h2)[0] if (keys %h2) > 0;
   if ($p1_gen ne $p2_gen){
      print STDERR $t[0], "\t", $t[1], "\t", join(":", @par1), "\t", join(":", @par2), "\t", $p1_gen, "\t", $p2_gen, "\n";
      %transform=();
      @ks = map{$_.$_} (split /\//, $t[1]); print STDERR "\@ks: ", $ks[0], "\t", $ks[1], "\n";;
      next unless @ks == 2;
      if ($p1_gen =~ /N/ or (not $is_homo->($p1_gen))){
        print STDERR "p1_gen: ", $p1_gen, "\t*", $is_homo->($p1_gen), "\n";
        $index = $p2_gen eq $ks[0]?1:($p2_gen eq $ks[1]?0:"NA");
        if ($index =~ /\D/){print STDERR $index, "p1: $p1_gen\n"; next}
        $p1_gen = $ks[$index]
      }
      if ($p2_gen =~ /N/ or (not $is_homo->($p2_gen))){
        print STDERR "p2_gen: ", $p2_gen, "\n";
        $index = $p1_gen eq $ks[0]?1:($p1_gen eq $ks[1]?0:"NA");
        if ($index =~ /\D/){print STDERR $index, "p2: $p2_gen\n"; next}
        $p2_gen = $ks[$index]
      }
      print STDERR $t[0], "\t", $t[1], "\t", join(":", @par1), "\t", join(":", @par2), "\t", $p1_gen, "\t", $p2_gen, "\n";
      $transform{$p1_gen} = "A"; $transform{$p2_gen} = "B"; $transform{substr($p1_gen,0,1) . substr($p2_gen,0,1)}="H"; $transform{substr($p2_gen,0,1) . substr($p1_gen,0,1)}="H";
      @geno = ();
      map{push @geno, exists $transform{$_}?$transform{$_}:"-"}@t[11..$#t];
      print STDERR join(" ", @t[11..$#t]), "\n", join(" ", @geno), "\n";
      print join("\t", @t[0..10], @geno), "\n";
   }
} ' $1 $2
