#!/usr/bin/perl -w
#
# hmp2structure.pl
#
# Get a STRUCTURE input file from a hapmap formatted SNP data file
#
# July 9, 2014
# Liz Cooper

use strict;

# From the command line arguments, collect the following information:
# The input and output file names,
# The minimum coverage desired for each locus
# The minimum Minor Allele Frequency (MAF) desired for each locus
# A flag indicating whether or not to use the linkage model (discouraged without phasing)
# A population file if the PopData option is going to be used (tab-delimited, same names as hmp file)
# A location file if the LocData option is going to be used (same format as PopData file)
my ($USAGE) = "$0 <input.hmp.txt> <output.structure> <Min. coverage> <Min. MAF> <Linkage Model?> <popData.txt> <locData.txt>\n
\tinput.hmp.txt = An input file in the TASSEL hapmap format
\toutput.structure = The name of the structure input file to be created
\tMin. coverage = The minimum number of individuals required at a locus to include it (Integer)
\tMin.MAF = The minimum minor allele frequency at a locus to include it (Number between 0 and 1)
\tLinkage Model = Type <0> if not desired; <1> if desired
\t\tNote that the linkage model is discouraged without phased haplotype information!
\tpopData = (Optional) A file indicating population assignments for each individual; Type <NA> if not desired
\t\tIf used, the file should be tab delimited, with individual names in column 1 and integers indicating population assignments in the second column
\tlocData = (Optional) A file indicating location (or phenotype) information for each individual; Type <NA> if not desired
\t\tSame format as the popData file\n";
unless (@ARGV) {
  print $USAGE;
  exit;
}
my ($input, $output, $mincov, $minmaf, $linmodel, $popdata, $locdata) = @ARGV;

# Create a hash keyed by individual ID to save all of the genotypes at every saved position
# Create another hash keyed the individual order/index to keep track of PI number orders
# Create an array to save all of the position IDs
# Create an array to save the alternate allele at each position
my %genotypes = ();
my %pi_index = ();
my @positions = ();
my @alleles = ();

# Open the input hapmap file, and start processing each line
open (IN, $input) || die "\nUnable to open the file $input!\n";

FILELOOP: while (<IN>) {
  chomp $_;
  my @info = split(/\t/, $_);

  # Get all of the individual names from the first line of the file
  if ($_ =~ /^rs/) {
    my @names = @info[11..(scalar @info - 1)];
    for (my $n = 0; $n < scalar @names; $n++) {
      my $pi =  $names[$n];
      $genotypes{$pi} = '';
      $pi_index{$n} = $pi;
    }
    next FILELOOP;
  }

  # For the remaining lines in the file, get all of the genotypes at that position
  # Check if the position passes the minimum coverage and minimum minor allele frequency requirements
  # If so, store the genotypes for each inidividual, and save the position and the minor allele in sep. arrays
  my $posID = $info[0];
  my $altAllele = (split(/\//, $info[1]))[1];
  my @bases = @info[11..(scalar @info - 1)];
  @bases = map{
      my @p = split //, $_;
      $p[0] eq $p[1]?$p[0]:"K"
      }@bases;
  my $longstring = join('', @bases);

  # First, do a check on the minimum coverage requirement
  $mincov = 0 unless $mincov;
  my $tempstring = $longstring;
  $tempstring =~ s/N//g;
  if ((length $tempstring) < $mincov) {
    next FILELOOP;
  }

  # Next, check that the site meets the minimum minor allele frequency requirement
  my $snp_count = 0;
  for (my $p = 0; $p < length $longstring; $p++) {
    if (substr($longstring, $p, 1) =~ /$altAllele/) {
      $snp_count += 2;
    } elsif (substr($longstring, $p, 1) =~ /[MRWSYK]/) {
      $snp_count += 1;
    }
  }
  #my $maf = $snp_count/(length($longstring));
  #if (($maf < $minmaf) || ($maf > (1-$minmaf))) {
  #  next FILELOOP;
  #}

  # If the site meets all of the requirements, add the genotype to the individual string in the hash
  # Add the position to the positions list
  push (@positions, $info[0]);
  push (@alleles, $altAllele);
  for (my $i = 0; $i < length $longstring; $i++) {
    my $individual = $pi_index{$i};
    $genotypes{$individual} .= substr($longstring, $i, 1);
  }
}
close(IN);

# Open the output file, and print out the appropriate information (based on which model will be used)
open (OUT, ">$output") || die "\nUnable to open the file $output!\n";

# First, print out the row of marker names
my $marker_row = join("\t", @positions);
print OUT $marker_row, "\n";

# Check if the the Linkage Model is set; if so, need to calculate the intermarker distances and print them to the file
# If not, then can just skip this step
if ($linmodel == 1) {
  my @distances = ();
  my $current_chr = 0;
  my $prev_pos = 0;

  foreach my $marker (@positions) {
    my ($chr, $position) = split(/_/, $marker);
    $chr =~ s/^S//g;
    if ($chr == $current_chr) {
      my $dist = $position - $prev_pos;
      push (@distances, $dist);
      $prev_pos = $position;
    } else {
      my $dist = -1;
      push (@distances, $dist);
      $prev_pos = $position;
      $current_chr = $chr;
    }
  }

  my $distance_row = join("\t", @distances);
  print OUT $distance_row, "\n";
}

# If Population Data or Location Data are going to be used, then read in that file, and then print the genotypes in the order of the file
unless ($popdata =~ /NA/) {
 
  # Check if the location data option is also selected,
  # If so, read in the location file, and use the order of this file to print both population and location information
  # Read the popData file completely in, and store this info. in a hash
  unless ($locdata =~ /NA/) {
    my %popData = ();
    open (POP, $popdata) || die "\nUnable to open the file $popdata!\n";
    while (<POP>) {
      chomp $_;
      my @temp = split(/\t/, $_);
      $popData{$temp[0]} = $temp[1];
    }
    close(POP);
    open (LOC, $locdata) || die "\nUnable to open the file $locdata!\n";
    while (<LOC>) {
      chomp $_;
      my @temp = split(/\t/, $_);
      
      # Get the genotypes for this PI number, then create haplotypes, then print all info. to the output file
      my @hap_1 = '';
      my @hap_2 = '';
      
      my $genstring = $genotypes{$temp[0]};
      for (my $g = 0; $g < length $genstring; $g++) {
	my $gen = substr($genstring, $g, 1);
	if ($gen =~ /N/) {
	  push (@hap_1, '-9');
	  push (@hap_2, '-9');
	} elsif ($gen =~ /[MRWSYK]/) {
	  push (@hap_1, '0');
	  push (@hap_2, '1');
	} elsif ($gen =~ /$alleles[$g]/) {
	  push (@hap_1, '1');
	  push (@hap_2, '1');
	} else {
	  push (@hap_1, '0');
	  push (@hap_2, '0');
	}
      }
      my $h1 = join("\t", @hap_1);
      my $h2 = join("\t", @hap_2);

      print OUT $temp[0], "\t", $popData{$temp[0]}, "\t", "1\t", $temp[1], "\t", $h1, "\n";
      print OUT $temp[0], "\t", $popData{$temp[0]}, "\t", "1\t", $temp[1], "\t", $h2, "\n";
    }
    close(LOC);
  } else {

    # If there is no location data, but there is still population data, then open this file and print genotypes in that file order
    open (POP, $popdata) || die "\nUnable to open the file $popdata!\n";
    while (<POP>) {
      chomp $_;
      my @temp = split(/\t/, $_);

      # Get the genotypes for this PI number, then create haplotypes, then print all info. to the output file
      my @hap_1 = '';
      my @hap_2 = '';
      
      my $genstring = $genotypes{$temp[0]};
      for (my $g = 0; $g < length $genstring; $g++) {
	my $gen = substr($genstring, $g, 1);
	if ($gen =~ /N/) {
	  push (@hap_1, '-9');
	  push (@hap_2, '-9');
	} elsif ($gen =~ /[MRWSYK]/) {
	  push (@hap_1, '0');
	  push (@hap_2, '1');
	} elsif ($gen =~ /$alleles[$g]/) {
	  push (@hap_1, '1');
	  push (@hap_2, '1');
	} else {
	  push (@hap_1, '0');
	  push (@hap_2, '0');
	}
      }
      my $h1 = join("\t", @hap_1);
      my $h2 = join("\t", @hap_2);

      print OUT $temp[0], "\t", $temp[1], "\t", "1\t", $h1, "\n";
      print OUT $temp[0], "\t", $temp[1], "\t", "1\t", $h2, "\n";
    }
    close(POP);
  }
} else {

  # If there is no population data, check if there is location data instead
  # If so, then read and print the genotypes in the order of that file
  unless ($locdata =~ /NA/) {
    open (LOC, $locdata) || die "\nUnable to open the file $locdata!\n";
    while (<LOC>) {
      chomp $_;
      my @temp = split(/\t/, $_);
      
      # Get the genotypes for this PI number, then create haplotypes, then print all info. to the output file
      my @hap_1 = '';
      my @hap_2 = '';
      
      my $genstring = $genotypes{$temp[0]};
      for (my $g = 0; $g < length $genstring; $g++) {
	my $gen = substr($genstring, $g, 1);
	if ($gen =~ /N/) {
	  push (@hap_1, '-9');
	  push (@hap_2, '-9');
	} elsif ($gen =~ /[MRWSYK]/) {
	  push (@hap_1, '0');
	  push (@hap_2, '1');
	} elsif ($gen =~ /$alleles[$g]/) {
	  push (@hap_1, '1');
	  push (@hap_2, '1');
	} else {
	  push (@hap_1, '0');
	  push (@hap_2, '0');
	}
      }
      my $h1 = join("\t", @hap_1);
      my $h2 = join("\t", @hap_2);

      print OUT $temp[0], "\t", "1\t", $temp[1], "\t", $h1, "\n";
      print OUT $temp[0], "\t", "1\t", $temp[1], "\t", $h2, "\n";
    }
    close(LOC); 
  } else {

    # If there is no location data and no population data, then simply print the haplotypes in the order of the hapmap file
    my @inds = sort {$a <=> $b} (keys %pi_index);

    foreach my $ind (@inds) {
      my $indID = $pi_index{$ind};
      
      # Get the genotypes for this PI number, then create haplotypes, then print all info. to the output file
      my @hap_1 = '';
      my @hap_2 = '';
      
      my $genstring = $genotypes{$indID};
      for (my $g = 0; $g < length $genstring; $g++) {
	my $gen = substr($genstring, $g, 1);
	if ($gen =~ /N/) {
	  push (@hap_1, '-9');
	  push (@hap_2, '-9');
	} elsif ($gen =~ /[MRWSYK]/) {
	  push (@hap_1, '0');
	  push (@hap_2, '1');
	} elsif ($gen =~ /$alleles[$g]/) {
	  push (@hap_1, '1');
	  push (@hap_2, '1');
	} else {
	  push (@hap_1, '0');
	  push (@hap_2, '0');
	}
      }
      my $h1 = join("\t", @hap_1);
      my $h2 = join("\t", @hap_2);

      print OUT $indID, "\t1", "\t", $h1, "\n";
      print OUT $indID, "\t1", "\t", $h2, "\n";
    }
  }
}
close(OUT);

# Finally, print out the total number of individuals and the total number of loci used in the input file
my $numLoci = scalar @positions;
my $numIN = scalar (keys %pi_index);
print "Number of Individuals = ", $numIN, "\n";
print "Number of Loci = ", $numLoci, "\n";
exit;


exit;

