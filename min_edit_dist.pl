#!/usr/local/bin/perl -w
#############################################################################
# Program Description:
# This program calculates the minimum edit distance of two words entered at
# the command line using the version of Levenshtein distance in which
# insertions and deletions each have a cost of 1 and substitutions have a
# cost of 2. The program displays a table that shows the intermediate
# computations that the program made.
#
#############################################################################
#get the target and source words
#my ($n, $m) =@ARGV;

#my $mid = med($n, $m);
#print join("\n", $n, $m, $mid), "\n";

my ($fa, $fb) = @ARGV;
my %na = get_names($fa);
my %nb = get_names($fb);

my %record;
foreach my $m (keys %na){
    my $ind = 1;
    next if exists $nb{$m};
    foreach my $j(keys %nb){
        my $dist = med($m, $j);
        $record{$m} = [$j, $dist] unless defined $record{$m};
        $record{$m} = [$j, $dist] if $dist < $record{$m}->[1];
    }
}

foreach (keys %record){
    my @arr = @{$record{$_}};
    print join("\t", ($_, @arr)), "\n" if $arr[1]>=0 and $arr[1]<=4;
}



###
sub get_names
{
    my $file = shift;
    my %return;
    open(F, $file) or die;
    while(<F>){
        $return{$1}=1 if /^(\S+)/;
    }
    close F;
    return %return;
}


sub med {
    my ($n, $m) = @_;
    #put the target and source words (in lower case form) into an array
    @target = split (//, lc($n)); @source = split (//, lc($m));
    
    #initialize variables
    @distance = (); @temp = ();
    
    #initialize an array of an array
    push @distance, [@temp]; $distance[0][0] = 0;
    
    #intialize first row from 0 to source length
    for (0..$#source+1) { $distance[$_][0] = $_; }
    
    #initialize first column from 0 to target length
    for (0..$#target+1) { $distance[0][$_] = $_; }
    
    #check the distance for each character and store in the distance array
    for $i (1..$#source+1) {
        for $j (1..$#target+1) {
            #if the characters are equal the cost is zero
            #else the cost is two for substitution.
            if($source[$i-1] eq $target[$j-1]) { $cost = 0; }
            else { $cost = 2; }
    
            #set minimum cell cost from an insertion, deletion or substitution
            $min = $distance[$i-1][$j] + 1;                                                   #insertion cost
            if($distance[$i][$j-1] + 1 < $min) { $min = $distance[$i][$j-1] + 1; }            #deletion cost
            if($distance[$i-1][$j-1] + $cost < $min) {$min = $distance[$i-1][$j-1] + $cost; } #substitution cost
            $distance[$i][$j] = $min;                                                         #set cost in table
        }
    }
    
    #print computation table between the target and the source words
    $printedSource[0] = "#"; for $i (0..$#source) { $printedSource[$i+1] = $source[$i]; }
    
#    for ($i = $#distance; $i >= 0; $i--) {
#        print"$printedSource[$i]  "; for $j (0..$#{$distance[$i]}) { print "$distance[$i][$j]  "; }
#        print "\n";
#    }
#    
#    print "   #"; for $i (0..$#target) { print "  $target[$i]"; } print "\n";
    return $distance[$#source+1][$#target+1];
}
