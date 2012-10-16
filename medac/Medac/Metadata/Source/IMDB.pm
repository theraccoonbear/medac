package Medac::Metadata::Source::IMDB;

use Moose;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein;

my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
my $cookie_jar = HTTP::Cookies->new(); 
my $mech = WWW::Mechanize->new();
$mech->agent($ua_string);

my $IMDB_BASE_URL = 'http://www.imdb.com';

#my $home_url = 'http://www.tv.com';

my $search_cache = {};
my $show_cache = {};

sub search {
	my $self = shift @_;
	my $search = shift @_;
	my $search_type = shift @_ || 'tv_series';
	
	my $search_url = $IMDB_BASE_URL . '/search/title?title=' . $search . '&title_type=' . $search_type;
	my $ret_val = {};
	
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
			#print Dumper($entry);
			$entry->{year} =~ s/[^0-9]+//gi;
			$entry->{id} = $entry->{url};
			$entry->{id} =~ s/.+?\/([^\/]+)\/?$/$1/gi;
			push @{$ret_val}, $entry;
		}
		
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

sub getSeries {
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
	
	$mech->get($url);
	
	die unless ($mech->success);
	my $content = $mech->{content};
	
	my $details_scraper = scraper {
		process '#img_primary a img', 'image' => '@src';
		process '#overview-top p', 'synopsis' => 'TEXT';
		process 'td#overview-top div.star-box-details span[itemprop="ratingValue"]', 'rating' => 'TEXT';
	};
	
	$ret_val = $details_scraper->scrape($content);
	$ret_val->{title} = $get_what->{title};
	$ret_val->{year} = $get_what->{year};
	$ret_val->{id} = $get_what->{id};
	$ret_val->{url} = $get_what->{url};
	
	return $ret_val;
} # getSeries()

sub getEpisodes {
	my $self = shift @_;
	my $show = shift @_;
	
	my $ret_val = ();
	my $url = '';
	if (defined $show->{url}) {
		$url = $IMDB_BASE_URL . $show->{url} . 'epsiodes?season=1';
	} else {
		return $ret_val;
	}
	
	$mech->get($url);
	
}

1;