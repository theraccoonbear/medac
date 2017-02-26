package Medac::Search::NZB::Unified;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';
	
use Moose;
use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Printer;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use JSON::XS;
use URI::Escape;
	
	
has 'search_agents' => (
	is => 'rw',
	isa => 'ArrayRef[Medac::Search::NZB]',
	default => sub {
		return [];
	}
);

has '+cache_context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => sub {
		return __PACKAGE__;
	}
);

sub addAgent() {
	my $self = shift @_;
	my $agent = shift @_;
	
	if (!$self->search_agents) {
		$self->search_agents([]);
	}
	
	push @{$self->search_agents}, $agent;
}

sub searchMusic {
	my $self = shift @_;
	my $params = shift @_;
	my $results = [];
	
	foreach my $agent (@{$self->search_agents}) {
		my $new_results = $agent->searchMusic($params);
		$results = [(@$results, @$new_results)];
	}
	
	return $results;
}

sub searchMovies {
	my $self = shift @_;
	my $params = shift @_;
	my $results = [];
	
	foreach my $agent (@{$self->search_agents}) {
		my $new_results = $agent->searchMovies($params);
		$results = [(@$results, @$new_results)];
	}
	
	return $results;
}

sub searchTV {
	my $self = shift @_;
	my $params = shift @_;
	my $results = [];
	
	foreach my $agent (@{$self->search_agents}) {
		my $new_results = $agent->searchTV($params);
		$results = [(@$results, @$new_results)];
	}
	
	return $results;
}

1;