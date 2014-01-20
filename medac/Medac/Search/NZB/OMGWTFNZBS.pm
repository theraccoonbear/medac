package Medac::Search::NZB::OMGWTFNZBS;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';

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

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'api.omgwtfnzbs.org'
);

has '+port' => (
	is => 'rw',
	isa => 'Int',
	default => 443
);


has '+protocol' => (
	is => 'rw',
	isa => 'Str',
	default => 'https'
);

has 'apiKey' => (
	is => 'rw',
	isa => 'Str'
);


sub searchTV {
	my $self = shift @_;
	my $params = shift @_;
	my $terms = $params->{terms} or die "No search term";
	my $retention = $params->{retention} || 1600;
	my $filter = $params->{filter} || undef;
	
	my $results = $self->search($terms, '19,20', $retention);
	
	foreach my $nzb (@$results) {
		$nzb->{season} = 0;
		$nzb->{episode} = 0;
		$nzb->{video_quality} = 'unknown';
		$nzb->{video_codec} = 'unknown';
		
		if ($nzb->{release} =~ m/s(?<season>\d{1,2})e(?<episode>\d{1,2})/i) {
			$nzb->{season} = $+{season} * 1;
			$nzb->{episode} = $+{episode} * 1;
		}
		
		if ($nzb->{release} =~ m/(?<videoquality>((720|1080)[pi])|HDTV|WEB-DL|SDTV)/) {
			$nzb->{video_quality} = $+{videoquality};
		}
	}
	
	if ($filter) {
		my $nr = [];
		foreach my $nzb (@$results) {
			if (&$filter($nzb)) {
				push @$nr, $nzb;
			}
		}
		$results = $nr;
	}
	
	
	return $results;
}

sub search {
	my $self = shift @_;
	my $terms = shift @_;
	my $category = shift @_ || '19,20';
	my $retention = shift @_ || 1600;
	
	my $params = {
		search => $terms,
		catid => $category,
		eng => 1,
		api => $self->apiKey,
		user => $self->username,
		retention => $retention
	};
	
	my $url = $self->baseURL() . '/json/?' . $self->encodeParams($params);
	
	print "Pulling $url\n";
	my $page = $self->pullURL($url);
	print "done.\n";
	
	my $results = [];
	
	if ($page->{success}) {
		# peculiar this
		$page->{content} =~ s/\].*?$/\]/gis;
		$results = decode_json($page->{content})
	}
	
	
	return $results;
} # search()

1;
#https://api.omgwtfnzbs.org/json/?search=NOVA.S41E11&catid=19%2C20&eng=1&api=088e4af3aedbb5d99ecdf23197f2fe69&user=medac&retention=1600