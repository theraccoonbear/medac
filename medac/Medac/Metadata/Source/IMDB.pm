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

#my $home_url = 'http://www.tv.com';

my $search_cache = {};
my $show_cache = {};

sub search {
	my $self = shift @_;
	my $search = shift @_;
	my $search_type = shift @_ || 'tv_series';
	
	my $search_url = 'http://www.imdb.com/search/title?title=' . $search . '&title_type=' . $search_type;
	
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
	
	my $ret_val;
	foreach my $entry (@{$results->{entries}}) {
		#print Dumper($entry);
		$entry->{year} =~ s/[^0-9]+//gi;
		$entry->{id} = $entry->{url};
		$entry->{id} =~ s/.+?\/([^\/]+)\/?$/$1/gi;
		push @{$ret_val}, $entry;
	}
	return $ret_val;
}

sub searchMovie {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'feature');
}

sub searchSeries {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'tv_series');
}

sub getSeries {
	my $self = shift @_;
	my $get_what = shift @_;
	
	if (defined $get_what->{id}) {
		$get_what = $get_what->{id};
	}
	
	my $url = 'http://www.imdb.com/title/' . $get_what . '/';
	
	$mech->get($url);
	
	die unless ($mech->success);
	my $content = $mech->{content};
	
	my $details_scraper = scraper {
		process 'td#img_primary a img', 'image' => '@src';
		process '#maindetails_center_bottom div.article' => 'blocks[]' => scraper {
			while (my $x = shift @_) {
				print Dumper($x) . "\n----------------------------------\n";
			}
			#print Dumper(@_);
		}
	};
	
	return $details_scraper->scrape($content);
	
}

1;