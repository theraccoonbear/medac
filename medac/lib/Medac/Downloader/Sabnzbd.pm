package Medac::Downloader::Sabnzbd;
use lib '../..';

use Moose;

extends 'Medac::Downloader';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Data::Printer;
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

sub getStatus {
	my $self = shift @_;
	my $params = {
		mode => 'queue',
		output => 'json',
		apikey => $self->apiKey
	};
	my $url = $self->baseURL() . $self->encodeParams($params);
	my $resp = $self->pullURL($url);
	my $json = decode_json($resp->{content});
	my $results = [];
	#p($json);
	my $long_title = '';
	if ($json->{queue} && $json->{queue}->{slots}) {
		foreach my $dl (@{ $json->{queue}->{slots} }) {
			my ($h, $m, $s) = split(/:/, $dl->{timeleft});
			my $dle = {
				name => $dl->{filename},
				bytes => $dl->{mb} * 1000000,
				bytes_downloaded => ($dl->{mb} - $dl->{mbleft}) * 1000000,
				bytes_remaining => $dl->{mbleft} * 1000000,
				percent_complete => (($dl->{mb} - $dl->{mbleft}) / $dl->{mb}) * 100,
				status => $dl->{status},
				age => $dl->{avg_age},
				seconds_left => ($h * 60 * 60) + ($m * 60) + $s
			};
			if (length($dl->{filename}) > length($long_title)) {
				$long_title = $dl->{filename};
			}
			
			push @$results, $dle;
		}
	}
	
	return {
		meta => {
			title_length => length($long_title)
		},
		queue => $results
	};	
}

sub getCategories {
	my $self = shift @_;
	my $params = {
		mode => 'get_cats',
		output => 'json',
		apikey => $self->apiKey
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