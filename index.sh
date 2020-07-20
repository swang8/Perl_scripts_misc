perl -I/home/shichen.wang/perl5/lib/perl5 -MBio::DB::Fasta -e '@fs=@ARGV; foreach $f(@fs){print $f, "\n"; $gn=Bio::DB::Fasta->new($f)}' $1
