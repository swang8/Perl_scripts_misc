DIR=$1
S3=$2
PROFILE=$3

echo  Example:
echo
echo    sh  ./upload_to_s3.sh  ./19112Ind  \"s3://indigo.data-transfer/TAMU/\" indigo
echo
echo    This will upload data in the local folder \"19112Ind\" to S3 bucket \"s3://indigo.data-transfer/TAMU/19112Ind\"
echo    Use \"aws s3 --profile=indigo ls s3://indigo.data-transfer/TAMU/19112Ind/\" to check when uploading is done.

perl -MFile::Basename -e '$dir=shift; print $dir, "\n"; exit unless $dir;  $s3=shift; $s3=~s/\/$//; exit unless $s3;  $prof=shift || "txgen";  @fs=<$dir/*>;  $name=basename($dir); map{$f=basename($_);  $cmd="aws s3 --profile=$prof cp $_  ${s3}/${name}/$f "; print $cmd, "\n"; system($cmd) }@fs;'  $DIR $S3  $PROFILE

