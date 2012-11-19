package Medac::Provider;

use Moose;
#use Moose::Role;

with 'Medac::Config';
#with 'Medac::Queue';
#extends 'Medac::API';

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

has 'info' => (
  is => 'rw',
  isa => 'HashRef',
  default => sub {
    return {
      name => 'UnnamedProvider',
      host => {
				name => 'medac.localhost',
				path => '/media',
				user => 'guest',
				pass => 'gu35t',
				port => 22
      }
    };
  }
);

has 'queue' => (
  is => 'rw',
  isa => 'Medac::Queue',
  default => sub {
    return new Medac::Queue;
  }
);

sub readProvider {
  my $self = shift @_;
  my $pr_name = shift @_;
  
  my $dl_root = $self->drill(['paths','downloads']);
  
  if (! -d $dl_root) {
    $self->error("Download root does not exist: $dl_root");
  }
  
  my $provider_root = $dl_root . $pr_name;
  
  if (! -d $provider_root) {
    $self->error("Provider root does not exist: $provider_root");
  }
  
  my $provider_file = $provider_root . '/provider.json';
  
  if (! -f $provider_file) {
    $self->error("Provider file does not exist: $provider_file");
  }
  
  my $json = read_file($provider_file);
  my $obj = decode_json($json);
  $self->info($obj);
	$self->queue->loadProviderQueue($pr_name);
  #$self->queue($self->queue->loadProviderQueue($pr_name));
  
}

sub writeProvider {
  my $self = shift @_;
  
  if (! defined $self->info->{name}) {
    $self->error("No provider name set");
  }
  
}

1;