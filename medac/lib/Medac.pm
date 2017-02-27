package Medac;

use Moose::Role;

with 'Medac::Config';
#with 'Medac::Response';

use lib '..';
use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
#use Slurp;
use CGI;
use POSIX;
use Medac::API::Default;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);
use Moose::Util::TypeConstraints;

has 'provider' => (
	is => 'rw',
	isa => 'Str',
	default => 'Unnamed'
);

has 'req' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub{ return {}; }
);

sub providerName {
	my $self = shift @_;
	my $provider = shift @_;
	
	my $pr_name = $provider;
	
	if (ref $provider eq 'HASH' && defined $provider->{name}) {
		$pr_name = $provider->{name};
	} elsif (ref $provider eq 'Medac::Provider') {
		$pr_name = $provider->info->{name};
	}
	
	return $pr_name;
}

sub drillex {
	my $self = shift @_;
	my $obj = $self->config;;
	if (scalar @_ == 2) {
		 $obj = shift @_; #
	}
	my $bits = shift @_;
	
	my $default = '____________MISSING';
	
	my $val = $self->drill($obj, $bits, $default);
	
	return $val ne $default;	
}

sub drill {
	my $self = shift @_;
	my $obj = $self->config;;
	my $bits = []; # shift @_;
	my $default = undef;
	
	my $pcnt = scalar @_;
	
	if ($pcnt == 1) {
		#$obj = shift @_;
		$bits = shift @_;
	} elsif ($pcnt == 2) {
		$obj = shift @_;
		$bits = shift @_;
	} elsif ($pcnt == 3) {
		$obj = shift @_;
		$bits = shift @_;
		$default = shift @_;
	}
	
	
	#if (scalar @_ == 1) {
	#	$bits = shift @_;	
	#} else {
	#	$obj = shift @_;
	#	$bits = shift @_;	
	#}
	
	foreach my $bit (@{$bits}) {
		if (defined $obj->{$bit}) {
			$obj = $obj->{$bit};
		} else {
			$obj = $default;
			last;
		}
	}
	
	return $obj;
}

1;