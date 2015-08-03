#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Getopt::Long qw(:config no_ignore_case bundling);

my $usage = <<_EOUSAGE_;

#################################################################################
#
#  -c <string>     filename containing a list of commands to execute, one cmd per line.           
#
#  --CPU             Default: 1
#
###################################################################################


_EOUSAGE_

	;


my $cmds_file = "";
my $CPU = 1;


&GetOptions (
			 "c=s" => \$cmds_file,
			 "CPU=i" => \$CPU,
			 );

unless ($cmds_file) {
	die $usage;
}

my $log_dir = "cmds_log.$$";
mkdir($log_dir) or die "Error, cannot mkdir $log_dir";

## This is very cheap 'parallel-computing' !!!  :)

my $uname = `uname -n`;
chomp $uname;

print "SERVER: $uname, PID: $$\n";

main: {

	my %job_tracker;
	my @failed_jobs;
	
	my $num_running = 0;
	
	open (my $fh, $cmds_file) or die "Error, cannot open file $cmds_file";
	my $cmd_counter = 0;
	while (my $cmd = <$fh>) {
		
		chomp $cmd;
		$cmd_counter++;

		$num_running++;
		my $child = fork();
		
		if ($child) {
			# parent
			$job_tracker{$cmd_counter} = $cmd;
		}
		else {
			# child:
			my $ret = &run_cmd($cmd_counter, $cmd);
			exit($ret);
		}
		
	
		if ($num_running >= $CPU) {
			wait();
			my $num_finished = &collect_jobs(\%job_tracker, \@failed_jobs);
			for (1..$num_finished-1) {
				wait(); # reap other finished children to avoid accumulation of zombies
			}
			$num_running -= $num_finished;
		}
	}
	
	
	## collect remaining processes.
	while (wait() != -1) { };
	
	&collect_jobs(\%job_tracker, \@failed_jobs);
	
	# purge log directory
	`rm -rf $log_dir`;
	
	my $num_failed_jobs = scalar @failed_jobs;
	if ($num_failed_jobs == 0) {
		print "\n\nAll $cmd_counter jobs completed successfully! :) \n\n";
		exit(0);
	}
	else {
		# write all failed commands to a file.
		my $failed_cmd_file = "failed_cmds.$$.txt";
		open (my $ofh, ">$failed_cmd_file") or die "Error, cannot write to $failed_cmd_file";
		print $ofh join("\n", @failed_jobs) . "\n";
		close $ofh;
		
		print "\n\nSorry, $num_failed_jobs of $cmd_counter jobs failed.\n\n"
			. "Failed commands written to file: $failed_cmd_file\n\n";
		exit(1);
	}
}

	
####
sub run_cmd {
	my ($index, $cmd) = @_;

	print "\nRUNNING: $cmd\n";
	
	my $ret = system($cmd);
		
	if ($ret) {
		print STDERR "Error, command: $cmd died with ret $ret";
	}
	
	open (my $log_fh, ">$log_dir/$index.ret") or die "Error, cannot write to log file for $index.ret";
	print $log_fh $ret;
	close $log_fh;


	return($ret);
}


####
sub collect_jobs {
	my ($job_tracker_href, $failed_jobs_aref) = @_;

	my @job_indices = keys %$job_tracker_href;

	my $num_finished = 0;

	foreach my $index (@job_indices) {
		
		my $log_file = "$log_dir/$index.ret";
		
		if (-s $log_file) {
			my $ret_val = `cat $log_file`;
			chomp $ret_val;
			my $job = $job_tracker_href->{$index};
			if ($ret_val == 0) {
				# hurray, job succeded.

				print "SUCCESS[$index]: $job\n";
				
			}
			else {
				# job failed.
				print "FAILED[$index]: $job\n";
				push (@$failed_jobs_aref, $job_tracker_href->{$index});
			}
			
			unlink $log_file;
			$num_finished++;
		}
	}

	return($num_finished);
}

