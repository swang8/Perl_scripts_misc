
#!perl -w
use strict;
use Getopt::Long;
use GD;
use GD::Simple;
use IO::File;

my @files;  ## each file contains "marker  postion" pairs, the order of files will determine the order of parallel plots.
my @link_files;
# each link file contains markers that are linked(shared) between two files, 
# assuming the first link_file is for linking file_1 and file_2; the second would be for linking file_2 and file_3 ...
my $output_prefix;

GetOptions(
  "files=s{1,}" => \@files,
  "links=s{1,}" => \@link_files,
  "output=s" => \$output_prefix
);

@files = split(",", join(",", @files));
@link_files = split (",", join(",", @link_files));

my %marker_pos = read_map_files(@files);
my %links = read_link_files(@link_files);

## create a new image;
my ($img_width, $img_height) = (800, 1600);
my $img = GD::Simple->new($img_width, $img_height);
my %margins = ();
@margins{qw(bottom left top right)} = (20, 20, 20, 20); ## margins for bottom, left, top, right;

my $VERTICAL_BAR_HEIGHT = 1; # 100% of plotting region's height
my $VERTICAL_BAR_WIDTH = 0.1;  # 10% of plotting region's width

my $bar_width = $VERTICAL_BAR_WIDTH * ($img_width - $margins{"left"} - $margins{"right"});
my $bar_height = $VERTICAL_BAR_HEIGHT * ($img_height - $margins{"bottom"} - $margins{"top"});

my $bar_background = "antiquewhite";
my $marker_background = "blue";
my $marker_background_alternative = "azure";
my $link_color = 'black';

## Figure out the coordinates for each vertical bar;
my %bar_coordinates = calculate_bar_coordinates(@files);

## Figure out the coordinates of each marker
my %marker_coordinates = calcualte_marker_coordinates(\%marker_pos, \%bar_coordinates);

## draw vertical_bars
$img->bgcolor($bar_background);
$img->fgcolor("gray");
map{$img->rectangle(@$_)} values %bar_coordinates;
    
## draw markers on the bars;
foreach my $f(keys %marker_coordinates){
	$img->fgcolor($marker_background);
	my @markers  =keys %{$marker_coordinates{$f}};
	foreach my $ind ( 0 ..$#markers){
		my @p = @{$marker_coordinates{$f}{$markers[$ind]}};
		if($p[1] != $p[3]) { ## bin
			my $color = $marker_background_alternative;
			$img->bgcolor($color);
		}
		$img->rectangle(@p);
	}
}

## draw links between markers
$img->bgcolor($link_color);
$img->fgcolor("gray");
foreach my $ind (keys %links){
	my $fa = $files[$ind];
	my $fb = $files[$ind+1];

	my @markers = @{$links{$ind}};
	my $offset = 5;
	foreach my $m (@markers){
		next unless exists $marker_coordinates{$fa}{$m} and exists $marker_coordinates{$fb}{$m};
		my @moveto = ($marker_coordinates{$fa}{$m}->[2] + $offset,  ($marker_coordinates{$fa}{$m}->[1] + $marker_coordinates{$fa}{$m}->[3])/2);
		print STDERR join("\t", @moveto, $m), " Moveto\n" if $moveto[0] < 20 ;
		my @linkto = ($marker_coordinates{$fb}{$m}->[0] - $offset,  ($marker_coordinates{$fb}{$m}->[1] + $marker_coordinates{$fb}{$m}->[3])/2);
		print STDERR join("\t", @linkto, $m), " Linkto\n" if $linkto[0] < 20 ;
		$img->moveTo(@moveto);
		$img->lineTo(@linkto);
	}

}

## save to file
my $png_file = $output_prefix . ".png";

my $fh = IO::File->new( $png_file, '>' ) or die "Unable to open outfile - $!\n";
$fh->binmode;
$fh->print( $img->png );

## subroutines;
sub read_map_files{
	my @fs = @_;
	my %return;
	foreach my $f (@fs){
		open(IN, $f) or die;
		while(<IN>){
			chomp;
			my ($marker, $pos) = split /\s+/, $_;
			push @{$return{$f}}, [$marker, $pos];
		}
		close IN;
	}
		
	return %return;
}

sub read_link_files{
  my @fs = @_;
  my %return;
  foreach my $ind ( 0 .. $#fs){
	open (IN, $fs[$ind]) or die;
	while(<IN>){
		chomp;
		push @{$return{$ind}}, $_
	}
	close IN;
  }
  return %return;
}

sub calculate_bar_coordinates{
	my @fs = @_;
	my %return;
	
	my $bar_interval = ($img_width - $margins{"left"} - $margins{"right"} - $bar_width) / ($#fs);
	
	foreach my $ind (0 .. $#fs){
		my $x1 = $margins{"left"} + $ind * $bar_interval;
		my $y1 = $margins{"top"} + (1-$VERTICAL_BAR_HEIGHT) * ($img_height - $margins{"bottom"} - $margins{"top"}) / 2.0;
		my $x2 = $x1 + $bar_width;
		my $y2 = $y1 + $bar_height;
		$return{$fs[$ind]} = [$x1, $y1, $x2, $y2];
	}
	
	return %return;
}

sub max{
	my $max = shift;
	my @arr = @_;
	map{$max = $_ if $_ > $max}@arr;
	return $max;
}

sub min{
	my $min = shift;
	my @arr = @_;
	map{$min = $_ if $_ < $min}@arr;
	return $min;
}


sub calcualte_marker_coordinates {
	my ($marker_ref, $bar_cor_ref) = @_;
	my %return;
	foreach my $f (keys %$marker_ref){
		my $bar_cor = $bar_cor_ref->{$f};
		my @arr = @{$marker_ref->{$f}};
		my @pos = map{
			if($_->[1]=~/-/){split /-/, $_->[1]}
			else{$_->[1], $_->[1]}
		}@arr;
		
		my $min = min(@pos);
		my $max = max(@pos);
		
		my $unit = ($bar_height  ) / ($max - $min);  
		foreach my $ind (0 .. $#arr){
			my $marker = $arr[$ind]->[0];
			my $pos_ind = $ind * 2;
			my $x1 = $bar_cor->[0];
			my $x2 = $bar_cor->[2];
			my $y1 = $bar_cor->[1] + ($pos[$pos_ind] - $min) * $unit;
			my $y2 = $bar_cor->[1] + ($pos[$pos_ind+1] - $min) * $unit;
			$return{$f}{$marker} = [$x1, $y1, $x2, $y2];
		}
	}
	return %return;
}


 



