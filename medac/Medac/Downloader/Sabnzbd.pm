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
		cat => $cat
	};
	
	my $sab_url = $self->baseURL() . $self->encodeParams($params);
	my $resp = $self->pullURL($sab_url);
	return $resp->{content} =~ m/ok/i;
	#print "$sab_url\n";
	#print $resp->{content};
	#print "\n\n\n";
	#print "$sab_url\n\n";
	# http://localhost:8080/sabnzbd/api?mode=addurl&name=http://www.example.com/example.nzb&nzbname=NiceName
}

1;