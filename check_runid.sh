echo  "****"
echo  "Check which folder has the run ID."
echo  "Usage: sh check_runid.sh <runid, ie. 17165>"
echo  "****"

perl -e '$id=shift;  @fs=<*/runParameters.xml>; foreach $f(@fs){$r=`cat $f`; print $f, "\n" if $r=~/$id/} ' $1
