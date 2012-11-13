package Medac::API::Download;
#use lib '../../../medac/Medac';
use lib '..';
use Moose;

extends 'Medac::API::Default';

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
use Medac::Queue;

has 'exposed' => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub { return ['status','enqueue']; }
);

has 'queue' => (
	is => 'rw',
	isa => 'Medac::Queue',
	default => sub { return new Medac::Queue(); }
);

has 'provider' => (
	is => 'rw',
	isa => 'Str',
	default => 'Unknown'
);

#has queue => (
#	is => 'rw',
#	isa => 'HashRef',
#	default => sub { return {queue=>[]}; }
#);
#
#sub writeQueue {
#	my $self = shift @_;
#	
#	my $dl_dir = $self->drill($self->config, ['paths','downloads']);
#	
#	if (!$dl_dir) {
#		$self->error("No download path specified in config");
#	}
#	
#	my $prm = $self->drill($self->req,['params','posted']);
#	
#	if (!$prm) {
#		$self->error("Invalid parameters.  No posted data.");
#	}
#	
#	my $pr_name = $self->drill($prm, ['provider','name']);
#	
#	if (!$pr_name) {
#		$self->error('No provider name in request');
#	}
#	
#	my $pr_dl_dir = $dl_dir . $pr_name . '/';
#	
#	if (! -d $pr_dl_dir) {
#		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
#	}
#	
#	my $queue_file = $pr_dl_dir . 'queue.json';
#	
#	write_file($queue_file, encode_json($self->queue));
#	
#}
#
#sub readQueue {
#	my $self = shift @_;
#	
#	my $dl_dir = $self->drill($self->config, ['paths','downloads']);
#	
#	if (!$dl_dir) {
#		$self->error("No download path specified in config");
#	}
#	
#	my $prm = $self->drill($self->req,['params','posted']);
#	
#	if (!$prm) {
#		$self->error("Invalid parameters.  No posted data.");
#	}
#	
#	my $pr_name = $self->drill($prm, ['provider','name']);
#	
#	if (!$pr_name) {
#		$self->error('No provider name in request');
#	}
#	
#	my $pr_dl_dir = $dl_dir . $pr_name . '/';
#	
#	if (! -d $pr_dl_dir) {
#		mkdir $pr_dl_dir, 0775 or $self->error("Can't create DL path \"$pr_dl_dir\": $!");
#	}
#	
#	my $queue_file = $pr_dl_dir . 'queue.json';
#	my $queue = {
#							queue => [] 
#						};
#	
#	if (-f $queue_file) {
#		$queue = decode_json(read_file($queue_file) || encode_json($queue));
#	} else {
#		write_file($queue_file, encode_json($queue));
#	}
#	
#	eval {
#		$self->queue($queue);
#	};
#	#
#	#if ($@) {
#	#	$self->pr($@);
#	#} else {
#	#	$self->pr($self->queue);
#	#}
#	#print "AFTER";
#
#}

sub status {
  my $self = shift @_;
  my $params = shift @_;
	
  #$self->readQueue();
  
	my $prm = $self->drill($self->req,['params','posted']);
	
	if (!$prm) {
		$self->error("Invalid parameters.  No posted data.");
	}
	
	my $pr_name = $self->drill($prm, ['provider','name']);
	my $dl_root = $self->drill($self->config, ['paths', 'downloads']);
	my $resource = $self->drill($prm, ['resource','path']);
	
	if (!$pr_name) {
		$self->error('No provider name in request');
	} elsif (!$dl_root) {
		$self->error('No download path in config');
	} elsif (!$resource) {
		$self->error('No resource specified');
	}
	
	
	my $queue_dir = 'queue/' . $pr_name;
	my $dl_dir = $dl_root . $pr_name . '/';
	my $dl_path = $dl_dir . $resource;
	
	
	if (! -d $dl_dir) {
		mkdir $dl_path, 0775 or $self->error("Can't create DL path \"$dl_path\": $!");
	}
	
	
	my $size = 0;
	my $message = "Doesn't exist";
	my $exists = JSON::XS::false;
	if (-f $dl_path) {
	  my @FA = stat($dl_path);
	  $size = $FA[7];
	  $message = "Exists";
	  $exists = JSON::XS::true;
	}
	
	$self->json_pr({'size'=>$size,'exists'=>$exists}, $message);
  
}

sub enqueue {
	my $self = shift @_;
	my $params = shift @_;

	
	#$self->readQueue();
	#
	my $prm = $self->drill($self->req,['params','posted']);
	
	if (!$prm) {
		$self->error("Invalid parameters.  No posted data.");
	}
	
	my $provider = $self->drill($prm, ['provider','name']);
	my $queue = new Medac::Queue();
	$queue->readQueue($provider);
	
	$queue->enqueue($self->resource);
	
	$self->json_pr($self->resource, "File queued");
	#$self->pr($queue->queued());
		
}

1;
