package Medac::Metadata::Source::IMDB;

use Moose;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;

my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
my $cookie_jar = HTTP::Cookies->new(); 
my $mech = WWW::Mechanize->new();
$mech->agent($ua_string);

my $IMDB_BASE_URL = 'http://www.imdb.com';

#my $home_url = 'http://www.tv.com';

my $search_cache = {};
my $show_cache = {};
my $season_cache = {};

sub dist {
	my $self = shift @_;
	my $val_1 = shift @_;
	my $val_2 = shift @_;
	
	# normalize...
	$val_1 = lc($val_1);
	$val_2 = lc($val_2);
	$val_1 =~ s/\&/and/gi;
	$val_2 =~ s/\&/and/gi;
	$val_1 =~ s/^\s*(.+?)\s*$/$1/gi;
	$val_2 =~ s/^\s*(.+?)\s*$/$1/gi;
	$val_1 =~ s/\s{2,}/ /gi;
	$val_2 =~ s/\s{2,}/ /gi;
	
	return distance($val_1, $val_2);
}

sub search {
	my $self = shift @_;
	my $search = shift @_;
	my $search_type = shift @_ || 'tv_series';
	
	my $search_url = $IMDB_BASE_URL . '/search/title?title=' . $search . '&title_type=' . $search_type;
	my $ret_val = ();
	my @s_results;
	
	if (defined $search_cache->{$search_url}) {
		$ret_val = $search_cache->{$search_url};
	} else {
		
		$mech->add_header(Referer => 'http://www.imdb.com/search/title');
		
		#print Dumper($mech);
		
		$mech->get($search_url);
		
		
		
		die unless ($mech->success);
		my $content = $mech->{content};
		
		my $search_scraper = scraper {
			process 'table.results tr td.title', 'entries[]' => scraper {
				process 'a[href^="/title"]', 'title' => 'TEXT';
				process 'a[href^="/title"]', 'url' => '@href';
				process 'span.outline', 'synopsis' => 'TEXT';
				process 'span.year_type', 'year' => 'TEXT';
				
			}
		};
		
		my $results = $search_scraper->scrape($content);
		
		
		foreach my $entry (@{$results->{entries}}) {  
			$entry->{distance} = $self->dist($entry->{title}, $search);
			$entry->{year} =~ s/[^0-9]+//gi;
			$entry->{id} = $entry->{url};
			$entry->{id} =~ s/.+?\/([^\/]+)\/?$/$1/gi;
			push @s_results, $entry;
		}
		
		@s_results = sort {$a->{distance} <=> $b->{distance}} @s_results;
		
		$ret_val = \@s_results;
		$search_cache->{$search_url} = $ret_val;
	}
	
	return $ret_val;
} # search()

sub searchMovie {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'feature');
} # searchMovie()

sub searchSeries {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'tv_series,mini_series');
} # searchSeries()

sub getShow {
	my $self = shift @_;
	my $get_what = shift @_;
	my $ret_val = {};
	my $id = 0;
	
	if (!defined $get_what->{url}) {
		if (defined $get_what->{id}) {
			$get_what->{url} = "/title/" . $get_what->{id} . '/';
		} else {
			return $ret_val;
		}
	}
	
	my $url = $IMDB_BASE_URL .  $get_what->{url};
	
	my $cache_key = $get_what->{title};
	
	if (defined $show_cache->{$cache_key}) {
		$ret_val = $show_cache->{$cache_key};
		
	} else {
		$mech->get($url);
		
		die unless ($mech->success);
		my $content = $mech->{content};
		
		my $details_scraper = scraper {
			process '#img_primary a img', 'image' => '@src';
			process '#overview-top p[itemprop="description"]', 'synopsis' => 'TEXT';
			process 'td#overview-top div.star-box-details span[itemprop="ratingValue"]', 'rating' => 'TEXT';
			process 'div.article .txt-block a[href^="episodes?season="]', 'seasons[]' => 'TEXT';
		};
		
		
		
		$ret_val = $details_scraper->scrape($content);
		my $s_list = {};
		
		foreach my $s (@{$ret_val->{seasons}}) {
			$s_list->{$s} = {};
		}
		$ret_val->{seasons} = $s_list;
		
		$ret_val->{title} = $get_what->{title};
		$ret_val->{year} = $get_what->{year};
		$ret_val->{id} = $get_what->{id};
		$ret_val->{url} = $get_what->{url};
		$show_cache->{$cache_key} = $ret_val;
	}
	
	return $ret_val;
} # getShow()

sub getSeason {
	my $self = shift @_;
	my $show = shift @_;
	my $season = shift @_ || 1;
	
	$season += 0;
	
	my $ret_val = ();
	my $url = '';
	
	if (defined $show->{url}) {
		
		my $referer = $IMDB_BASE_URL . $show->{url};
		$url = $IMDB_BASE_URL . $show->{url} . 'episodes?season=' . $season;
		
		my $cache_key =  $show->{title} . '::' . $season;
		
		if (defined $season_cache->{$cache_key}) {
			$ret_val = $season_cache->{$cache_key};
		} else {
			#$mech->add_header(Referer => $referer);
			$mech->get($url);
		
			die unless ($mech->success);
			my $content = $mech->{content};
			
			my $dom = Mojo::DOM->new($content);
			my $eps = $dom->find('.list_item');
			my @ep_list = [];
			for my $ep ($eps->each) {
				my $ep_entry = {
					'image' => $ep->find('div.image img')->[0]->{src},
					'url' => $ep->find('a[itemprop="url"]')->[0]->{href},
					'name' => $ep->find('a[itemprop="name"]')->[0]->text,
					'episode_number' => $ep->find('meta[itemprop="episodeNumber"]')->[0]->{content} + 0,
					'synopsis' => $ep->find('div[itemprop="description"]')->[0]->text				 
				};
				$ep_list[$ep_entry->{episode_number}] = $ep_entry;
			}
			
			$ret_val = \@ep_list;
			$season_cache->{$cache_key} = $ret_val;
		}
	} else {
		return $ret_val;
	}
	
	return $ret_val;
} # getSeason()

1;