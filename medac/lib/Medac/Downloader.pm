package Medac::Downloader;
use lib '..';

use Moose;

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
	'isa' => 'Str',
	'default' => 'username'
);

has 'password' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => '********'
);

has 'apiKey' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => '********'
);

has 'mech' => (
	'is' => 'rw',
	'isa' => 'WWW::Mechanize',
	'default' => sub {
		my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
		my $cookie_jar = HTTP::Cookies->new();
		$cookie_jar->clear();
		my $www_mech = WWW::Mechanize->new(
			cookie_jar => $cookie_jar,
			SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
			PERL_LWP_SSL_VERIFY_HOSTNAME => 0,
			verify_hostname => 0,
			ssl_opts => {
				verify_hostname => 0
			}
		);
		$www_mech->agent($ua_string);
		return $www_mech;
	}
);

sub pullURL {
	my $self = shift @_;
	my $url = shift @_;
	
	my $ret = {
		success => 0,
		content => ''
	};
	
	$self->mech->get($url);
	if ($self->mech->success) {
		$ret->{success} = 1;
		$ret->{content} = $self->mech->{content};
	}
	
	return $ret;
}

sub encodeParams {
	my $self = shift @_;
	my $list = shift @_;
	my $nl = [];
	foreach my $name (keys %$list) {
		push @$nl, $self->encodeParam($name, $list->{$name});
	}
	
	return join('&', @$nl);
}

sub encodeParam {
	my $self = shift @_;
	my $name = shift @_;
	my $value = shift @_;
	
	return uri_escape($name) . '=' . uri_escape($value);
}



1;