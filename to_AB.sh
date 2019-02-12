perl -ne '
BEGIN{$r=`wc -l $ARGV[0]`; $r+=0;  $is_homo = sub{$seq=$_; @p=split //, $seq; return $p[0] eq $p[1]} } 
chomp; 
@t=split /\s+/,$_; 
$n++; 
if($n <= $r){$snp{$t[0]}=1}
else{
  $m++; 
  if($m==1){
     map{if($t[$_]=~/TAM111/){push @arr1, $_} if($t[$_]=~/TAM112/){push @arr2, $_} }1..$#t; 
     print $_, "\n"; next} 
   next unless exists $snp{$t[0]};  
   @par1=@t[@arr1]; @par2=@t[@arr2]; 
   %h1=(); %h2=();  
   map{$h1{$_}++ unless /N/}@par1; map{$h2{$_}++ unless /N/}@par2; 
   $p1_gen="NN"; $p1_gen = (sort{$h1{$b} <=> $h1{$a}}keys %h1)[0] if (keys %h1) > 0; 
   $p2_gen="NN"; $p2_gen = (sort{$h2{$b} <=> $h2{$a}}keys %h2)[0] if (keys %h2) > 0;  
   if ($p1_gen ne $p2_gen){
      print STDERR join(":", @par1), "\t", join(":", @par2), "\t", $p1_gen, "\t", $p2_gen, "\n"; 
      %transform=();
      %count=(); map{$count{$_}++ unless /N/}@t[11..$#t];
      @ks =(); map{push @ks, $_ if $is_homo->($_)} keys %count;
      next unless @ks == 2;
      if ($p1_gen =~ /N/ or not $is_homo->($p1_gen)){
        $index = $p2_gen eq $ks[0]?1:($p2_gen eq $ks[1]?0:"NA");
        next if $index =~ /\D/;
        $p1_gen = $ks[$index]
      }
      if ($p2_gen =~ /N/ or not $is_homo->($p2_gen)){
        $index = $p1_gen eq $ks[0]?1:($p1_gen eq $ks[1]?0:"NA");
        next if $index =~ /\D/;
        $p2_gen = $ks[$index]
      }
      $transform{$p1_gen} = "A"; $transform{$p2_gen} = "B";
      @geno = ();
      map{push @geno, exists $transform{$_}?$transform{$_}:"-"}@t[11..$#t];
      print STDERR join(" ", @t[11..$#t]), "\n", join(" ", @geno), "\n";
      print join("\t", @t[0..10], @geno), "\n";
   }
}
