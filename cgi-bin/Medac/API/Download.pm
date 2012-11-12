package Medac::API::Download;
#use lib '../../../medac/Medac';

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

has 'exposed' => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub { return ['status','enqueue']; }
);


has queue => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { return []; }
);

sub readQueue {
	my $self = shift @_;
	
	my $cfg = defined $self->config ? $self->config : decode_json(slurp('../medac/config.json'));
	
	my $pr_name = $self->drill($self->req, ['params','posted','provider','name']);
	my $dl_root = $self->drill($self->config, ['paths', 'downloads']);
	
	if (!$pr_name) {
		$self->error('No provider name in request');
	} elsif (!$dl_root) {
		$self->error('No download path in config');
	}
	
	
	my $queue_dir = 'queue/' . $pr_name;
	my $dl_path = $dl_root . $pr_name . '/';
	
	
	
	$self->pr({
		'queue_dir' => $queue_dir,
		'dl_path' => $dl_path
	});
	#my $queue_dir = 'queue/' . $request->{provider}->{name};
}

sub status {
  my $self = shift @_;
  my $params = shift @_;
	
  $self->readQueue();
  
  if ($params->{named}->{path}) {
    my $file = $params->{named}->{path};
    
    if (-f $file) {
      
    } else {
      
    }
  } else {
    $self->error("No path supplied");
  }
  
}

sub enqueue {
	my $self = shift @_;
	my $params = shift @_;
	
	$self->json_pr($params, 'Called ENQUEUE!');
}

1;
