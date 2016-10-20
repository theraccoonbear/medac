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
	$nzb->{year} = '????';
	$nzb->{age} = $now - (($nzb->{usenetage} || 0) * 1);
	$nzb->{age_days} = $nzb->{age} / 60 / 60 / 24;
	$nzb->{imdb} = '';
	
	my $quality_map = {
		'web-dl' => 'Web',
		'bdrip' => 'B-Ray',
		'brrip' => 'B-Ray',
		'hdrip' => 'HDRip',
		'vhsrip' => 'VHS',
		'cam' => 'Cam'
	};
	
	if ($nzb->{release} =~ m/(?<audio>DD5.1)/) {
		$nzb->{audio} = $+{audio};
	}
	
	if ($nzb->{release} =~ m/(?<year>(19|20)\d{2})/) {
		$nzb->{year} = $+{year};
	}

	if ($nzb->{release} =~ m/s(?<season>\d{1,4})e(?<episode>\d{1,2})/i) {
		$nzb->{season} = $+{season} * 1;
		$nzb->{episode} = $+{episode} * 1;
	}
	
	if ($nzb->{release} =~ m/(?<videoquality>((480|720|1080)[pi])|HDTV|HDRIP|WEB-DL|SDTV|DVD|PDTV|B[RD]RIP|VHSRIP|CAM)/i) {
		
		$nzb->{video_quality} = $quality_map->{lc($+{videoquality})} || $+{videoquality};
	}
	
	if ($nzb->{release} =~ m/(?<videocodec>(xvid|x264))/i) {
		$nzb->{video_codec} = $+{videocodec};
	}
	
	if ($nzb->{weblink} && $nzb->{weblink} =~ m/\/(?<imdb>tt\d+)$/) {
		$nzb->{imdb} = $+{imdb};
	}
	
	
	if ($nzb->{release} =~ m/REPACK/) {
		$nzb->{repack} = 1;
	}
	
	return $nzb;
	
} # parseRelease()

1;