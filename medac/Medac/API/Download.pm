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
	default => sub { return ['status','enqueue','dequeue','queue_status']; }
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
#	my $params = shift @_;

	my $prm = $self->drill($self->req,['params','posted']);
	
	if (!$prm) {
		$self->error("Invalid parameters.  No posted data.");
	}
	
	my $provider = $self->drill($prm, ['provider','name']);
	my $queue = new Medac::Queue();
	$queue->readQueue($provider);
	
	$queue->enqueue($self->resource);
	
	$self->json_pr($self->resource, "File queued");
}

sub dequeue {
	my $self = shift @_;
	
	my $prm = $self->drill($self->req,['params','posted']);
	
	if (!$prm) {
		$self->error("Invalid parameters.  No posted data.");
	}
	
	my $provider = $self->drill($prm, ['provider','name']);
	my $queue = new Medac::Queue();
	$queue->readQueue($provider);
	
	my $msg = "File not in queue";
	my $exists = $queue->inQueue($self->resource);
	if ($exists > 0) {
		$queue->dequeue($self->resource);
		$msg = "File dequeued";
	}
	
	$self->json_pr({dequeued => $exists > 0 ? JSON::XS::true : JSON::XS::false}, $msg);
	
}

sub queue_status {
	my $self = shift @_;
	
	my $prm = $self->drill($self->req,['params','posted']);
	my $provider = $self->drill($prm, ['provider','name']);
	my $queue = new Medac::Queue();
	$queue->readQueue($provider);
	
	my $queue_root = $queue->queueRoot();
	
	my $flist = [];;
	
	foreach my $f (@{$queue->queued()}) {
		my $full_path = $queue_root . $f->{path};
		
		my $nfe = {
			'md5' => $f->{md5},
			'path' => $f->{path},
			'size' => $f->{size},
			'exists' => -f $full_path ? JSON::XS::true : JSON::XS::false,
			'downloaded' => -f $full_path ? (stat $full_path)[7] : 0
		};
		
		push @{$flist}, $nfe;
	}
	
	
	$self->json_pr($flist);
}

1;
