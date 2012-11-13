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
	
	my $in_queue = 0 == 1;
	foreach my $qfile (@{$self->queued}) {
		if ($qfile->{md5} eq $resource->{md5}) {
			$in_queue = 1 == 1;
		}
	}
	
	if ($in_queue) {
		$self->json_pr({already_queued => JSON::XS::true}, "File already queued");
	} else {
		push @{$self->queued()}, $resource;
		$self->writeQueue();
		$self->json_pr({already_queued => JSON::XS::false}, "File enqueued");
	}
	
	
	
	
}


1;