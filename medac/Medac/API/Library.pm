package Medac::API::Library;
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
	default => sub { return ['fetch', 'subscribe']; }
);
	
sub fetch {
	my $self = shift @_;
	my $provider = shift @_ || undef;
	
	#$self->pr($provider);
	#
	#$provider = $self->drill($provider, ['numerical',0]);
	
	my $lib_path = $self->config->drill(['paths','root']) . '/' . $self->config->drill(['paths','json']) . '/media.json';
	if (defined $provider) {
		$lib_path = $self->config->drill(['paths','downloads']) . $provider . '/media.json';
	}
	
	
	if (! -f $lib_path) {
		$self->error("Couldn't find media library: $lib_path");
	}
	
	my $json = read_file($lib_path);
	$self->json_pr({'library'=>$json}, "Library found");
	
}

sub subscribe {
	my $self = shift @_;
	my $provider_name = shift @_;
	
	if (!defined $provider_name) {
		$self->error("No provider name supplied");
	}
	
	$self->json_pr({'retrieved'=>$provider_name},"Subscribed");
	
	
	#my $who = 
}
	

1;
