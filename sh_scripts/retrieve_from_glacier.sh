profile_name=$1
vault_name=$2
archive_ID=$3
file_name=$4

echo "profile_name=\$1"
echo "vault_name=\$2"
echo "archive_ID=\$3"
echo "file_name=\$4"

perl -e '($profile_name, $vault_name, $archive_ID, $file_name) = @ARGV; 
# initiate the job
$init_cmd = qq(aws --profile=$profile_name glacier initiate-job --account-id - --vault-name $vault_name --job-parameters \047{"Type": "archive-retrieval"\, "ArchiveId":"$archive_ID"}\047);
print $init_cmd, "\n";
$init_msg = `$init_cmd`;
$init_jobid=$1 if $init_msg=~/jobId\":\s+\"(\S+)\"/;
print "Jobid: ", $init_jobid, "\n";

$job_status = `aws --profile=$profile_name glacier describe-job --account-id - --vault-name $vault_name --job-id $init_jobid`;

# check if ready for download
while ($job_status !~ /Completed\":\s+true/){
$code=$1 if $job_status=~/(StatusCode\":\s+\S+)\,/;
$t = localtime(time);
print $t, "\t", $code, "\n";
sleep(600);
$job_status = `aws --profile=$profile_name glacier describe-job --account-id - --vault-name $vault_name --job-id $init_jobid`;
}

# download;
$down = "aws --profile=$profile_name glacier get-job-output --account-id - --vault-name $vault_name --job-id $init_jobid $file_name";
print "Downloading $file_name\n";
`$down`;


' $profile_name $vault_name $archive_ID $file_name

#aws --profile=$profile_name glacier initiate-job --account-id - --vault-name $vault_name --job-parameters '{"Type": "archive-retrieval", "ArchiveId":"$archive_ID"}'
#aws --profile=$profile_name glacier get-job-output --account-id - --vault-name $vault_name --job-id $jobID $file_name


