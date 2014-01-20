package Medac::Search::NZB;
use lib '../..';

use Moose;

extends 'Medac::Search';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use JSON::XS;
use URI::Escape;

has 'hostname' => (
	is => 'rw',
	isa => 'Str'
);

has 'port' => (
	is => 'rw',
	isa => 'Int',
	default => 80
);

has 'protocol' => (
	is => 'rw',
	isa => 'Int',
	default => 'http'
);

has 'username' => (
	is => 'rw',
	isa => 'Str'
);

has 'password' => (
	is => 'rw',
	isa => 'Str'
);

has 'apiKey' => (
	is => 'rw',
	isa => 'Str'
);


sub baseURL() {
	my $self = shift @_;
	
	my $url = $self->protocol . '://' . $self->hostname . ':' .$self->port;
	return $url;
}

1;