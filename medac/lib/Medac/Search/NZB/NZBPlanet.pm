package Medac::Search::NZB::NZBPlanet;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Date::Parse;
use Data::Printer;
use Text::Levenshtein qw(distance);
use Medac::Cache;
use JSON::XS;
use URI::Escape;

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'api.nzbplanet.net'
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
	return [];
}

sub searchMovies {
	my $self = shift @_;
	my $params = shift @_;
	my $terms = $params->{terms} or die "No search term";
	my $retention = $params->{retention} || 1600;
	my $filter = $params->{filter} || undef;
	my $results = [];
	
	my $extra = {
		cat => 2000
	};
	
	my $base_res = $self->search($params->{terms}, 'search', $extra);
	
	if (ref $results ne 'ARRAY') {
		print STDERR "Error with NZBPlanet!\n";
		p($results);
		return [];
	}

	foreach my $nzb (@$base_res) {
		$nzb->{release} = $nzb->{title};
		$nzb = $self->parseRelease($nzb, {provider => 'NZBPlanet'});
		push @$results, $nzb;
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
	my $results = [];
	my $filter = $params->{filter} || undef;
	
	my $extra = {
		category => 5000
	};
	if ($params->{season} && $params->{season} =~ m/^\d+$/) {
		$extra->{season} = $params->{season};
	}
	if ($params->{episode} && $params->{episode} =~ m/^\d+$/) {
		$extra->{episode} = $params->{episode};
	}
	
	my $base_res = $self->search($params->{terms}, 'tvsearch', $extra);
	
	foreach my $nzb (@$base_res) {
		$nzb->{release} = $nzb->{title};
		$nzb = $self->parseRelease($nzb, {provider => 'NZBPlanet'});
		push @$results, $nzb;
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
	my $category = shift @_ || 'tvsearch';
	my $extra = shift @_ || {};
	my $results = [];
	
	my $params = {
		q => $terms,
		t => $category,
		apikey => $self->apiKey,
		o => 'json',
		extended => 1
	};
	
	foreach my $k (keys %$extra) {
		$params->{$k} = $extra->{$k};
	}
	
	
	my $url = $self->baseURL() . '/api?' . $self->encodeParams($params);

	my $page = $self->pullURL($url);
	
	my $init_results = decode_json($page->{content});

	if (
		! $init_results->{channel} ||
		! $init_results->{item}
	) {
		return $results;
	}

	# handle single result
	my $items = $init_results->{channel}->{item};
	if (ref $items ne 'ARRAY') {
		$items = [$items];
	}
	
	foreach my $item (@{ $items }) {
		foreach my $attr_item(@{ $item->{attr} }) {
			my $name = $attr_item->{'@attributes'}->{name};
			my $val = $attr_item->{'@attributes'}->{value};
			if ($item->{$name}) {
				if (ref($item->{$name}) ne 'ARRAY') {
					$item->{$name} = [$item->{$name}, $val];
				} else {
					push @{ $item->{$name} }, $val;
				}
			} else {
				$item->{$name} = $val;
			}
		}
		
		delete $item->{'attr'};
		
		if ($item->{season}) {
			$item->{season} =~ s/[^\d]+//g;
			$item->{season} *= 1;
		}
		
		if ($item->{episode}) {
			$item->{episode} =~ s/[^\d]+//g;
			$item->{episode} *= 1;
		}
		$item->{release} = $item->{title};
		$item->{sizebytes} = $item->{size};
		$item->{getnzb} = $item->{link};
		$item->{usenetage} = str2time($item->{usenetdate});
		$item->{search_provider} = __PACKAGE__;
		push @$results, $item;
	}
	
	return $results;
} # search()

1;