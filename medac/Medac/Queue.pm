package Medac::Queue;

use Moose;

extends 'Medac::API';

use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);

has queued => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { return []; }
);

sub readQueue {
	my $self = shift @_;
	my $provider = shift @_ || $self->provider;
	
	$self->provider($provider);
	
	my $dl_dir = $self->config->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $provider->{name} . '/';
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
	}
	
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		write_file($provider_file, encode_json($provider));
	}
	
	my $queue_file = $pr_dl_dir . 'queue.json';
	my $queue = [];
	
	if (-f $queue_file) {
		$queue = decode_json(read_file($queue_file) || encode_json($queue));
	} else {
		write_file($queue_file, encode_json($queue));
	}
	
	eval {
		$self->queued($queue);
	};
}

sub writeQueue {
	my $self = shift @_;
	my $provider = shift @_ || $self->provider;
	
	my $dl_dir = $self->config->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	$self->provider($provider);
	
	my $pr_dl_dir = $dl_dir . $provider->{name} . '/';
	
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
	}
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		write_file($provider_file, encode_json($provider));
	}
	
	
	my $queue_file = $pr_dl_dir . 'queue.json';
	
	write_file($queue_file, encode_json($self->queued));
}

sub enqueue {
	my $self = shift @_;
	my $resource = shift @_;
	
	my $in_queue = $self->inQueue($resource);
	
	if (defined $in_queue) {
		$self->json_pr({already_queued => JSON::XS::true}, "File already queued");
	} else {
		push @{$self->queued()}, $resource;
		$self->writeQueue();
		$self->json_pr({already_queued => JSON::XS::false}, "File enqueued");
	}
}

sub dequeue {
	my $self = shift @_;
	my $resource = shift @_;
	
	my $idx = $self->inQueue($resource);
	
	my $message = "Not in queue";
	if (defined $idx) {
		splice(@{$self->queued}, $idx, 1);
		$self->writeQueue();
		$message = "Removed";
	}
	
	$self->json_pr({removed => defined $idx}, $message);
	
}

sub queueRoot {
	my $self = shift @_;
	my $provider = shift @_ || $self->provider;
	
	my $dl_dir = $self->config->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $provider->{name} . '/';
	
	return $pr_dl_dir;
}

sub inQueue {
	my $self = shift @_;
	my $file = shift @_;
	
	my $md5 = defined $file->{md5} ? $file->{md5} : $file;
	
	my $found = 0;
	my $pos = 0;
	foreach my $q_file(@{$self->queued}) {
		if ($q_file->{md5} eq $file->{md5}) {
			$found = 1;
			last;
		}
		$pos++;
	}
	
	return $found == 1 ? $pos : undef;
}

sub loadProviderQueue {
	my $self = shift @_;
	my $pr_name = shift @_;
	
	my $dl_dir = $self->config->drill(['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $pr_name . '/';
	if (! -d $pr_dl_dir) {
		$self->error("Provider download directory doesn't exist");
	}
	
	my $provider_file = $pr_dl_dir . 'provider.json';
	if (! -f $provider_file) {
		$self->error("Provider metadata doesn't exist");
	}
	
	my $json = decode_json(read_file($provider_file));
	#print Dumper($json); exit;
	
	$self->provider($json);
	$self->readQueue();
}


1;