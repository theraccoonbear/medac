package Medac::Search::TV::TheTVDB;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Printer;
use Text::Levenshtein qw(distance);
use Medac::Cache;
use JSON::XS;
use URI::Escape;
use Web::Scraper;

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'www.thetvdb.com'
);

has '+port' => (
	is => 'rw',
	isa => 'Int',
	default => 80
);


has '+protocol' => (
	is => 'rw',
	isa => 'Str',
	default => 'http'
);


has '+cache_context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => sub {
		return __PACKAGE__;
	}
);

has 'exclude_section' => (
	'is' => 'rw',
	'isa' => 'ArrayRef',
	default => sub {
		return [];
	}
);


sub search {
	my $self = shift @_;
	my $terms = shift @_;
	
	#http://thetvdb.com/?string=SEARCHTERM&searchseriesid=&tab=listseries&function=Search
	my $params = {
		string => $terms,
		searchseriesid => '',
		tab => 'listseries',
		function => 'Search'
	};
	
	my $url = $self->baseURL() . '/?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	
	my $results = [];
	
	if ($page->{success}) {
		my $content = $page->{content};
	
	  
		my $scraper = scraper {
			process '#listtable tr', 'entries[]' => scraper {
				process 'td:nth-child(1) a', 'name' => 'TEXT', 'url' => '@href';
				process 'td:nth-child(2)', 'language' => 'TEXT';
				process 'td:nth-child(3)', 'id' => 'TEXT';
			};
		};
		
		my $scr_rslt = $scraper->scrape($content);
		
		$results = $scr_rslt->{entries};
		shift @$results;
	}
	
	
	return $results;
} # search()

sub fetchShow {
	my $self = shift @_;
	my $id = shift @_;
	
	#http://thetvdb.com/?tab=series&id=SHOWID&lid=7
	my $params = {
		tab  => 'series',
		id => $id,
		lid => 7
	};
	
	my $url = $self->baseURL() . '/?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	
	my $results = {};
	
	if ($page->{success}) {
		my $content = $page->{content};
	
	  
		my $scraper = scraper {
			process '#content h1', 'name' => 'TEXT';
			process '#content', 'description' => 'TEXT';
			process '.seasonlink', 'seasons[]' => sub {
				my $season_id  = $_->attr('href');
				$season_id =~ s/^.+?seasonid=(\d+).+$/$1/;
				if ($season_id =~ m/^\d+$/) {
					$_->as_trimmed_text() => $season_id;
				}
			}
		};
		
		my $scr_rslt = $scraper->scrape($content);
		$scr_rslt->{description} =~ s/^\s+//;
		$scr_rslt->{description} =~ s/^$scr_rslt->{name}//;
		my %seasons = @{ $scr_rslt->{seasons} };
		$scr_rslt->{seasons} = {};
		foreach my $s (keys %seasons) {
			if (length($s) > 0) {
				$scr_rslt->{seasons}->{$s} = $seasons{$s};
			}
		}
		
		$results = $scr_rslt;
	}
	
	
	return $results;
	
}

sub getEpisodes {
	my $self = shift @_;
	my $show_id = shift @_;
	my $season = shift @_ || undef;
	
	# http://thetvdb.com/?tab=seasonall&id=71991&lid=7
	my $params = {
		tab => 'seasonall',
		id => $show_id,
		lid => 7
	};
	
		my $url = $self->baseURL() . '/?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	
	my $results = [];
	
	if ($page->{success}) {
		my $content = $page->{content};
	
	  
		my $scraper = scraper {
			process '#listtable tr', 'episodes[]' => scraper {
				process 'td:nth-child(1) a', 'season_ep' => 'TEXT';
				process 'td:nth-child(2) a', 'name' => 'TEXT';
				process 'td:nth-child(3)', 'air_date' => 'TEXT';
			}
		};
		
		my $scr_rslt = $scraper->scrape($content);
		
		shift @{ $scr_rslt->{episodes} };

		my $ing_count = {};
		
		foreach my $ep (@{ $scr_rslt->{episodes} }) {
			my $season_num = 0;
			my $ep_num = 0;
			my $iron_chef = '???';
			my $challenger = '???';
			my $ingredient = '???';
			my $overtime = ($ep->{name} =~ m/\bovertime\b/gi);
			
			if ($ep->{season_ep} =~ m/(?<seasonNum>\d+)\s*x\s*(?<episodeNum>\d+)/) {
				$season_num = $+{seasonNum};
				$ep_num = $+{episodeNum}
			}
			
			if ($ep->{name} =~ m/^(?<iron_chef>.+?)\svs/) {
				$iron_chef = $self->trim($+{iron_chef});
			}
			
			if ($ep->{name} =~ m/vs\.?\s*(?<challenger>[^\(]+?)\(/) {
				$challenger = $+{challenger};
				$challenger =~ s/\s*Overtime\s*//gi;
				$challenger = $self->trim($challenger);
			}
			
			if ($ep->{name} =~ m/\((?<ingredient>[^\)]+)\)/) {
				$ingredient = $self->trim($+{ingredient});
			}
			
			if (! defined $ing_count->{$ingredient}) {
				$ing_count->{$ingredient} = 1;
			} else {
				$ing_count->{$ingredient}++;
			}
			
			
			
			my $new_ep = {
				name => $ep->{name},
				season_episode => $ep->{season_ep},
				season => $season_num,
				episode => $ep_num,
				air_date => $ep->{air_date},
				overtime => $overtime,
				iron_chef => $iron_chef,
				challenger => $challenger,
				ingredient => $ingredient,
				ingredient_count => $ing_count->{$ingredient}
			};
			
			if (defined $season) {
				if ($season_num eq $season) {
					push @$results, $new_ep;
				}
			} else {
				push @$results, $new_ep;
			}
		}
		#shift @$results;
		
	}
	
	
	return $results;
	
}

1;