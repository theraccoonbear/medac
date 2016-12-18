use Moops;

use lib '../../..';

class Medac::Search::NZB::Unified extends Medac::Search::NZB {
	
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
	
	method addAgent(Medac::Search::NZB $agent) {
		if (!$self->search_agents) {
			$self->search_agents([]);
		}
		
		#p($self->search_agents);
		push @{$self->search_agents}, $agent;
	}
	
	method searchMusic {
		my $params = shift @_;
		my $results = [];
		
		foreach my $agent (@{$self->search_agents}) {
			my $new_results = $agent->searchMusic($params);
			$results = [(@$results, @$new_results)];
		}
		
		return $results;
	}
	
	method searchMovies {
		my $params = shift @_;
		my $results = [];
		
		
		#p($self);
		#p($self->search_agents);
		#die;
		
		foreach my $agent (@{$self->search_agents}) {
			my $new_results = $agent->searchMovies($params);
			$results = [(@$results, @$new_results)];
		}
		
		return $results;
	}
	
	method searchTV {
		my $params = shift @_;
		my $results = [];
		
		foreach my $agent (@{$self->search_agents}) {
			my $new_results = $agent->searchTV($params);
			$results = [(@$results, @$new_results)];
		}
		
		return $results;
	}
}
