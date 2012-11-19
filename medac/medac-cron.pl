#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

BEGIN {
	my $script_path = __FILE__;
	$script_path =~ s/\/[^\/]+$//gi;
	unshift @INC, $script_path;
}

use Medac::Config;
use Medac::API;
use Medac::Queue;
use Medac::Provider;

my $rsync_tag = 'MEDAC_RSYNC_ACTIVE';

my $ps = `ps aux`;

sub logMsg {
	my $msg = shift @_ || 'no message';
	my $status = shift @_ || 'stat';
	
	print "[$status] $msg\n";
}

sub errMsg {
	my $msg = shift @_;
	
	logMsg($msg, 'error');
	exit(0);
}

sub warnMsg {
	my $msg = shift @_;
	
	logMsg($msg, 'warn');
}

if ($ps =~ m/$rsync_tag/g) {
	errMsg("instance in progress, exiting");
	exit 0;
} else {
	#my $cfg = new Medac::Config();
	my $api = new Medac::API(context => 'local');
	#my $cfg = $api->config;
	#my $cfg = bless($api->config;
	#my $queue = new Medac::Queue();
	
	
	my $dl_root = $api->drill(['paths','downloads']);
	
	
	if (! -d $dl_root) {
		errMsg("DL root missing: $dl_root");
	}
	
	opendir (DFH, $dl_root) or errMsg("Can't read from DL root: $!");
	my @FILES = readdir DFH;
	closedir DFH;
	foreach my $d (@FILES) {
		if ($d !~ m/[^-_A-Za-z0-9]/gi) {
			if ($d !~ m/^\.{1,2}/gi) {
				my $provider_name = $d;
				my $prov_queue_dir = $dl_root . $provider_name;
				my $prov_queue_path = $prov_queue_dir . '/queue.json';
				logMsg("Checking provider $provider_name");
				
				my $pr_obj = new Medac::Provider();
				$pr_obj->readProvider($provider_name);
				
				my $queue = $pr_obj->queue->queued;
					
				if (scalar @{$queue} < 1) {
					logMsg("  - Nothing queued; skipping.");
				} else {
					logMsg("  - " . scalar @{$queue} . " downloads in queue");
					
					foreach my $qfile (@{$queue}) {
						my $qfile_path = $prov_queue_dir . $qfile->{path};
						my $exists = -f $qfile_path;
						
						#print Dumper($pr_obj->info);
						
						my $pr_host_name = $pr_obj->info->{host}->{name};
						my $pr_host_port = $pr_obj->info->{host}->{port};
						my $pr_host_user = $pr_obj->info->{host}->{user};
						(my $pr_host_path = $pr_obj->info->{host}->{path}) =~ s/\/$//gi;
						
						my $cmd = "echo \"{$rsync_tag}\" > /dev/null && rsync -avz --progress --partial --append -e \"ssh -p $pr_host_port\" $pr_host_user\@$pr_host_name:$pr_host_path$qfile->{path} $qfile_path";
						
						logMsg("  - $cmd");
						
						if ($exists) {
							my $downloaded = (stat $qfile_path)[7];
							if ($downloaded eq $qfile->{size}) {
								logMsg("  - Download 100% complete; dequeing: $qfile_path");
								$pr_obj->queue->dequeue($qfile);
							} else {
								my $percent = $downloaded / $qfile->{size};
								logMsg("  - Download $percent\% complete: $qfile_path ");
							}
						} else { # -f $qfile_path
							logMsg("  - Download not started: $qfile->{path}");
						} # -f qfile_path
					} # foreach (@{$queue})
				} # empty queue?
			} # neither . nor ..
		} # clean identifier name
	} # foreach (@FILES)
	
	
	
	#my $cmd = 'echo "' . $rsync_tag . '" > /dev/null && rsync -avz --progress --partial --append --files-from /home/don/code/theraccoonshare.com/public_html/medac-dev/cgi-bin/queue/theraccoonbearcity/queue.txt -e "ssh -p 22" guest@medac-dev.snm.com:/home/don/Desktop/Video/ /home/don/Desktop/MedacDownloads/theraccoonbearcity';
	#`$cmd`;
	#print "$cmd\n";
	
	exit 0;
}
