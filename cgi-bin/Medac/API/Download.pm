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
	
	my $prm = $self->drill($self->req,['params','posted']);
	
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
