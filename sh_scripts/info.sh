zcat $1 | perl -ne 'next unless /^>/; $chr=$1 if />(\S+)/; @t=split /:/, $_; print join("\t", "\@SQ", "SN:".$chr, "LN:".$t[-2]), "\n"'   >${1}_info
