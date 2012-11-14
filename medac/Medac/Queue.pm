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

#has 'config' => (
#  is => 'rw',
#  isa => 'HashRef',
#  default => sub { return decode_json(slurp('../medac/config.json')); }
#);

has 'provider' => (
	is => 'rw',
	isa => 'Str',
	default => 'Unknown'
);

has queued => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { return []; }
);

sub readQueue {
	my $self = shift @_;
	my $provider = shift @_;
	
	my $dl_dir = $self->drill($self->config, ['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	$self->provider($provider);
	
	my $pr_dl_dir = $dl_dir . $provider . '/';
	
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
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
	
	my $dl_dir = $self->drill($self->config, ['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	$self->provider($provider);
	
	my $pr_dl_dir = $dl_dir . $provider . '/';
	
	if (! -d $pr_dl_dir) {
		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
	}
	
	my $queue_file = $pr_dl_dir . 'queue.json';
	
	write_file($queue_file, encode_json($self->queued));
}

sub enqueue {
	my $self = shift @_;
	my $resource = shift @_;
	
	my $in_queue = $self->inQueue($resource);
	
	#my $in_queue = 0 == 1;
	#foreach my $qfile (@{$self->queued}) {
	#	if ($qfile->{md5} eq $resource->{md5}) {
	#		$in_queue = 1 == 1;
	#	}
	#}
	
	if ($in_queue) {
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
	if ($idx) {
		splice(@{$self->queued}, $idx - 1, 1);
		$self->writeQueue();
		$message = "Removed";
	}
	
	$self->json_pr({removed => $idx > 0}, $message);
	
}

sub queueRoot {
	my $self = shift @_;
	my $provider = shift @_ || $self->provider;
	
	my $dl_dir = $self->drill($self->config, ['paths','downloads']);
	
	if (!$dl_dir) {
		$self->error("No download path specified in config");
	}
	
	my $pr_dl_dir = $dl_dir . $provider . '/';
	
	return $pr_dl_dir;
}

sub inQueue {
	my $self = shift @_;
	my $file = shift @_;
	
	my $md5 = defined $file->{md5} ? $file->{md5} : $file;
	
	my $found = 0;
	my $pos = 1;
	foreach my $q_file(@{$self->queued}) {
		if ($q_file->{md5} eq $file->{md5}) {
			$found = 1;
			last;
		}
		$pos++;
	}
	
	return $found == 1 ? $pos : 0;
}


1;