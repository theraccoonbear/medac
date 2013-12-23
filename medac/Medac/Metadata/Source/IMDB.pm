package Medac::Metadata::Source::IMDB;
use lib '../../..';

use Moose;

use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use URI::Escape;

my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
my $cookie_jar = HTTP::Cookies->new(); 
my $mech = WWW::Mechanize->new();
$mech->agent($ua_string);

my $IMDB_BASE_URL = 'http://www.imdb.com';

#my $home_url = 'http://www.tv.com';

has 'search_cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub { return new Medac::Cache('context'=>'IMDBSearch'); }
);

has 'show_cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub { return new Medac::Cache('context'=>'IMDBShow'); }
);

has 'season_cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub { return new Medac::Cache('context'=>'IMDBSeason'); }
);

#my $search_cache = {};
#my $show_cache = {};
#my $season_cache = {};

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

sub find {
	my $self = shift @_;
	my $terms = shift @_;
	my $search_type = shift @_ || 0;
	
	my $type_map = {
		"All" => "&s=all",
		"Name" => "&s=nm&ref_=fn_nm",
		"Title" => "&s=tt&ref_=fn_tt",
		"Movie" => "&s=tt&ttype=ft&ref_=fn_ft",
		"TV" => "&s=tt&ttype=tv&ref_=fn_tv",
		"TV Episode" => "&s=tt&ttype=ep&ref_=fn_ep",
		"Video Game" => "&s=tt&ttype=vg&ref_=fn_vg",
		"Character" => "&s=ch&ref_=fn_ch",
		"Company" => "&s=co&ref_=fn_co",
		"Keyword" => "&s=kw&ref_=fn_kw"
	};
	
	$search_type = $type_map->{$search_type} ? $search_type : "All";
	
	my $search_filter = $type_map->{$search_type};
	
	my $search_url = $IMDB_BASE_URL . '/find?q=' . uri_escape($terms) . $search_filter;
	my $cache_key = "RESPONSE:$search_url";
	
	my $ret_val = ();
	my $content = '';
	my @s_results;
	
	#if ($self->search_cache->hit($search_url)) {
		#$ret_val = $self->search_cache->retrieve($search_url);
	if ($self->search_cache->hit($cache_key)) {
		$content = $self->search_cache->retrieve($cache_key);
	} else {
		
		$mech->add_header(Referer => 'http://www.imdb.com/');

		print "URL: $search_url\n";
		
		$mech->get($search_url);
		
		die unless ($mech->success);
		$content = $mech->{content};
		
	}
	
	$self->search_cache->store($cache_key, $content);
		
	# SX{{width}}_CR0,0,{{width}},{{height}}_.jpg
	# poster: http://ia.media-imdb.com/images/M/MV5BMTI4NzI5NzEwNl5BMl5BanBnXkFtZTcwNjc1NjQyMQ@@._V1_SX128_CR0,0,128,44_.jpg
	
	my $search_scraper = scraper {
		process '.findSection', 'sections[]' => scraper {
			process '.findSectionHeader', 'name' => 'text';
			process 'findSectionHeader a', 'id' => '@name';
			process '.findList tr', 'entries[]' => scraper {
				process 'td.primary_photo a', 'url' => '@href';
				process 'td.primary_photo a img', 'poster' => '@src';
				process 'td.result_text > a', 'url' => '@href', 'title' => 'TEXT';
				process 'td.result_text small a', 'show_title' => 'TEXT', 'show_url' => '@href';
				process 'td.result_text small', 'show_specifics' => 'TEXT';
				process 'td.result_text', 'meta' => 'TEXT';
				process 'td' => 'check' => sub { return '...'; };
			}
		}
	};
		
		
		
	$ret_val = $search_scraper->scrape($content);
	
	foreach my $sec (@{$ret_val->{sections}}) {
		#print "$sec->{name} : $sec->{id}\n";
		foreach my $entry (@{$sec->{entries}}) {
			my $meta = $entry->{meta};
			my $replace = $entry->{show_specifics};
			$replace =~ s/\(/\\\(/gi;
			$replace =~ s/\)/\\\)/gi;
			$replace = qr($replace);
			$meta =~ s/\s*$replace\s*//gis;
			$entry->{year} = 0;
			#print "$meta\n";
			if ($meta =~ m/\((?<year>(19|20)\d{2})\)/gis) {
				$entry->{year} = $+{year};
			}
			$meta =~ s/\((\d+|TV[^\)]+)\)//g;
			$meta =~ s/\s+/ /gi;
			$meta =~ s/^\s+//gi;
			$meta =~ s/\s+$//gi;
			
			$entry->{new_meta} = $meta;
			#print Dumper($entry);
			#print "$sec => $sec_type->{entries}->{$sec}\n";
		}
	}
	#exit(0);
	
	#$self->search_cache->store($search_url, $ret_val);
	
	return $ret_val;
	
} # find()

sub search {
	
	
	my $self = shift @_;
	my $search = shift @_;
	my $search_type = shift @_ || 'tv_series';
	
	
	
	
	$search =~ s/ and$/ &/gi;
	$search =~ s/^and /& /gi;
	$search =~ s/ and / & /gi;
	
	my $search_url = $IMDB_BASE_URL . '/search/title?title=' . $search . '&title_type=' . $search_type;
	my $ret_val = ();
	my @s_results;
	
	if ($self->search_cache->hit($search_url)) {
		$ret_val = $self->search_cache->retrieve($search_url);
	} else {
		
		$mech->add_header(Referer => 'http://www.imdb.com/search/title');

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
		$self->search_cache->store($search_url, $ret_val);
		#Medac::Cache->cache("search:$search_url", $ret_val);
	}
	
	return $ret_val;
} # search()

sub searchMovie {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'feature,tv_movie,documentary,short,video');
} # searchMovie()

sub searchSeries {
	my $self = shift @_;
	my $title = shift @_;
	return $self->search($title, 'tv_series,mini_series,tv_special');
} # searchSeries()

sub getMovie {
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
	
	if ($self->show_cache->hit($cache_key)) {
		$ret_val = $self->show_cache->retrieve($cache_key);
		
	} else {
		$mech->get($url);
		
		die unless ($mech->success);
		my $content = $mech->{content};
		
		my $details_scraper = scraper {
			process '#img_primary a img', 'image' => '@src';
			process '#overview-top p[itemprop="description"]', 'synopsis' => 'TEXT';
			process 'td#overview-top div.star-box-details span[itemprop="ratingValue"]', 'rating' => 'TEXT';
			process 'div.article .txt-block a[href^="episodes?season="]', 'seasons[]' => 'TEXT';
			process 'div[itemprop="actors"] a', 'actors[]' => {url => '@href', 'name' => 'TEXT'};#scraper {
			#	process '[itemprop="url"]', 'url' => '@href';
			#	process 'span', 'name', 'TEXT';
			#}
		};
		
		
		
		$ret_val = $details_scraper->scrape($content);
		my $s_list = {};
		
		#foreach my $s (@{$ret_val->{seasons}}) {
		#	$s_list->{$s} = {};
		#}
		#$ret_val->{seasons} = $s_list;
		
		$ret_val->{title} = $get_what->{title};
		$ret_val->{year} = $get_what->{year};
		$ret_val->{id} = $get_what->{id};
		$ret_val->{url} = $get_what->{url};
		
		$self->show_cache->store($cache_key, $ret_val);
	}
	
	return $ret_val;
} # getMovie()

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
	
	if ($self->show_cache->hit($cache_key)) {
		$ret_val = $self->show_cache->retrieve($cache_key);
		
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
		$self->show_cache->store($cache_key, $ret_val);
	}
	
	return $ret_val;
} # getShow()

sub getSeason {
	my $self = shift @_;
	my $show = shift @_;
	my $season = shift @_ || 1;
	
	if ($season =~ m/^\d+/) {
		$season += 0;
	}
	
	my $ret_val = ();
	my $url = '';
	
	if (defined $show->{url}) {
		
		my $referer = $IMDB_BASE_URL . $show->{url};
		$url = $IMDB_BASE_URL . $show->{url} . 'episodes?season=' . $season;
		
		my $cache_key =  $show->{title} . '::' . $season;
		
		if ($self->season_cache->hit($cache_key)) {
			$ret_val = $self->season_cache->retrieve($cache_key);
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
					'synopsis' => $ep->find('div[itemprop="description"]')->[0]->text,
					'season_number' => $season
				};
				
				$ep_list[$ep_entry->{episode_number}] = $ep_entry;
			}
			
			$ret_val = \@ep_list;
			$self->season_cache->store($cache_key, $ret_val);
		}
	} else {
		return $ret_val;
	}
	
	return $ret_val;
} # getSeason()

sub dumpCache {
	my $self = shift @_;
	
	print "SEARCH:\n";
	$self->search_cache->dump();
	print "SHOW:\n";
	$self->show_cache->dump();
	print "SEASON:\n";
	$self->season_cache->dump();
}

1;