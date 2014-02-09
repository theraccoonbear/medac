package Medac::Downloader::Sabnzbd;
use lib '../..';

use Moose;

extends 'Medac::Downloader';

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

sub baseURL {
	my $self = shift @_;
	my $url = $self->protocol . '://' . $self->hostname . ':' .$self->port . '/sabnzbd/api?';
	return $url;
}

sub getCategories {
	my $self = shift @_;
	my $params = {
		mode => 'get_cats',
		output => 'json',
		apikey => '470de9b72ee542337629b7c3c87d51d4'
	};
	
	my $url = $self->baseURL() . $self->encodeParams($params);
	my $resp = $self->pullURL($url);
	my $json = decode_json($resp->{content});
	return $json->{categories} ? $json->{categories} : [];
}

sub queueDownload {
	my $self = shift @_;
	my $url = shift @_;
	my $name = shift @_;
	my $cat = shift @_;
	
	my $params = {
		mode => 'addurl',
		name => $url,
		nzbname => $name,
		apikey => $self->apiKey,
		cat => $cat,
		output => 'json'
	};
	
	my $sab_url = $self->baseURL() . $self->encodeParams($params);
	my $resp = $self->pullURL($sab_url);
	my $json = decode_json($resp->{content});
	#print Dumper($json);
	#print Dumper($json->{status});
	#print Dumper($json->{status} ? 'Y' : 'N');
	#exit(0);
	return $json->{status} ? 1 : 0;
}

1;