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

has '+cache_context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => sub {
		return __PACKAGE__;
	}
);


sub baseURL() {
	my $self = shift @_;
	
	my $url = $self->protocol . '://' . $self->hostname . ':' .$self->port;
	return $url;
}

sub parseRelease {
	my $self = shift @_;
	my $nzb = shift @_;
	my $opts = shift @_;
	
	my $now = time;
	
	$nzb->{season} = 0;
	$nzb->{episode} = 0;
	$nzb->{video_quality} = '????';
	$nzb->{video_codec} = '????';
	$nzb->{audio} = '????';
	$nzb->{repack} = 0;
	$nzb->{age} = $now - (($nzb->{usenetage} || 0) * 1);
	$nzb->{age_days} = $nzb->{age} / 60 / 60 / 24;
	
	if ($nzb->{release} =~ m/(?<audio>DD5.1)/) {
		$nzb->{audio} = $+{audio};
	}
	
	
	if ($nzb->{release} =~ m/s(?<season>\d{1,4})e(?<episode>\d{1,2})/i) {
		$nzb->{season} = $+{season} * 1;
		$nzb->{episode} = $+{episode} * 1;
	}
	
	if ($nzb->{release} =~ m/(?<videoquality>((480|720|1080)[pi])|HDTV|WEB-DL|SDTV|DVD|PDTV|BDRiP)/) {
		$nzb->{video_quality} = $+{videoquality};
	}
	
	if ($nzb->{release} =~ m/(?<videocodec>(xvid|x264))/i) {
		$nzb->{video_codec} = $+{videocodec};
	}
	
	if ($nzb->{release} =~ m/REPACK/) {
		$nzb->{repack} = 1;
	}
	
	return $nzb;
	
} # parseRelease()

1;