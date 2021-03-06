package Medac::Search::NZB::OMGWTFNZBS;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Data::Printer;
use Text::Levenshtein qw(distance);
use Medac::Cache;
use JSON::XS;
use URI::Escape;

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'api.omgwtfnzbs.me'
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

has '+cache_context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => sub {
		return __PACKAGE__;
	}
);

sub searchMusic {
	my $self = shift @_;
	my $params = shift @_;
	my $terms = $params->{terms} or die "No search term";
	my $retention = $params->{retention} || 2000;
	my $filter = $params->{filter} || undef;
	
	my $results = $self->search($terms, '7,22', $retention);

	if (ref $results eq 'HASH' && $results->{notice}) {
		if ($results->{notice} !~ m/0 results/) {
			print STDERR "Error in OMGWTFNZBS!\n";
			print STDERR $results->{notice} . "\n\n";
		}
		return [];
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
	
	return [map { 
		my $opts =  {provider => 'OMGWTFNZBS'};
		if ($_->{categoryid} eq '7') { $opts->{audio} = 'mp3'; }
		if ($_->{categoryid} eq '22') { $opts->{audio} = 'flac'; }
		my $pn = $self->parseRelease($_, $opts);
		$pn; 
	} @$results];;
}

sub searchMovies {
	my $self = shift @_;
	my $params = shift @_;
	my $terms = $params->{terms} or die "No search term";
	my $retention = $params->{retention} || 2000;
	my $filter = $params->{filter} || undef;
	
	my $results = $self->search($terms, '15,16,17,18', $retention);
	
	if (ref $results eq 'HASH' && $results->{notice}) {
		if ($results->{notice} !~ m/0 results/) {
			print STDERR "Error in OMGWTFNZBS!\n";
			print STDERR $results->{notice} . "\n\n";
		}
		return [];
	}
	
	my $now = time;
	
	foreach my $nzb (@$results) {
		$nzb = $self->parseRelease($nzb, {provider => 'OMGWTFNZBS'});
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

sub searchTV {
	my $self = shift @_;
	my $params = shift @_;
	my $terms = $params->{terms} or die "No search term";
	my $retention = $params->{retention} || 2000;
	my $filter = $params->{filter} || undef;
	
	my $results = $self->search($terms, '19,20,21', $retention);
	
	my $now = time;
	if (ref $results eq 'HASH') {
		return [];
	}
	
	foreach my $nzb (@$results) {
		$nzb = $self->parseRelease($nzb, {provider => 'OMGWTFNZBS'});
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
	my $category = shift @_ || '19,20,21';
	my $retention = shift @_ || 2000;
	
	my $params = {
		search => $terms,
		catid => $category,
		eng => 1,
		api => $self->apiKey,
		user => $self->username,
		retention => $retention
	};
	
	my $url = $self->baseURL() . '/json/?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	
	my $results = [];
	
	if ($page->{success}) {
		$page->{content} =~ s/\].*?$/\]/gis;
		$page->{content} =~ s/^\s*//gis;
		$results = decode_json($page->{content})
	}
	
	return $results;
} # search()

1;