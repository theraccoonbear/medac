package Medac::Metadata::Source::CouchPotato;
use lib '../../..';

use Moose;

extends 'Medac::Metadata::Source';

use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Medac::Cache;
use URI::Escape;
use JSON::XS;
use XML::Simple;
use Digest::MD5 qw(md5);

our $sections = [];

has 'protocol' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'http'
);

has 'hostname' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'port' => (
	'is' => 'rw',
	'isa' => 'Int',
	'default' => 32400
);

has 'username' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'password' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'apiKey' => (
	'is' => 'rw',
	'isa' => 'Str'
);


has 'cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub {
		return new Medac::Cache('context'=>'CouchPotato');
	}
);

sub baseURL {
	my $self = shift;
	return $self->protocol . '://' . $self->hostname. ':' . $self->port . '/api/' . $self->apiKey;
}

sub pullURL {
	my $self = shift @_;
	my $url = shift @_;
	
	my $page = $self->SUPER::pullURL($url);
	if ($page->{content} =~ m/remember_me/) {
		my $fields = {
			'remember_me' => "1",
			'username' => $self->username,
			'password' => $self->password
		};
		my $resp = $self->mech->submit_form(
			form_number => 1,
			fields => $fields
		);
	}
	$page = $self->SUPER::pullURL($url);
	return $page;
}

sub managedMovies {
	my $self = shift @_;
	my $url = $self->baseURL(). '/media.list/?';
	my $page = $self->pullURL($url);
	return decode_json($page->{content})->{movies};
}



1;
