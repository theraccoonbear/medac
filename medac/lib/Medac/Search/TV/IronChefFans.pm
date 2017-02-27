package Medac::Search::TV::IronChefFans;
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
use List::Util qw(max);

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'filehouse.ironcheffans.info'
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

has 'max_bandwidth' => (
	is => 'rw',
	'isa' => 'Maybe[Str]',
	default => undef
);

sub getCategories {
	my $self = shift @_;
	
	my $parms = {};
	my $url = $self->baseURL() . '/index.php';
	my $page = $self->pullURL($url);
	
	
	my $results = {};
	
	if ($page->{success}) {
		my $content = $page->{content};
	
		my $scraper = scraper {
			process 'table', 'tables[]' => scraper {
				process 'tr.row1, tr.row2', 'entries[]' => scraper {
					process 'td:nth-child(1) a', 'title' => 'TEXT', 'id' => sub {
						#'@href';
						my $url = $_->attr('href');
						if ($url =~ m/id=(\d+)$/) {
							return $1;
						}
					};
					process 'td:nth-child(1) span', 'description' => 'TEXT';
				};
			}
		};
		
		my $scr_rslt = $scraper->scrape($content);
		
		$results = $scr_rslt->{tables}->[3]->{entries};
		pop @$results
	}
	
	
	return $results;
	
}

sub fetchCategoryPage {
	my $self = shift @_;
	my $params = shift @_;
	$params->{act} = 'category';
	
	my $url = $self->baseURL() . '/index.php?' . $self->encodeParams($params);
	
	print STDERR "Fetching $url...\n";
	
	my $page = $self->pullURL($url);
	my $results = {};
	
	if ($page->{success}) {
		my $content = $page->{content};
	  
		my $anchor_rgx = qr/^(?<ingredient>.+?)(\s+\((?<overtime>.+?)\sOT\))?\s*-\s*(?<iron_chef>.+?)\s*[Vv][Ss]\.?\s*(?<challenger>.+?)$/;
		my $span_rgx = qr/^(?<ingredient>.+?)\s*\((?<season>\d+)(?<episode>\d{2})(OT)?\)/;
		
		my $scraper = scraper {
			process 'table', 'tables[]' => scraper {
				process 'tr.row1, tr.row2', 'entries[]' => scraper {
					process 'td:nth-child(2) a', 'iron_chef' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $anchor_rgx) {
							return $+{iron_chef}
						}
					},
					'challenger' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $anchor_rgx) {
							return $+{challenger}
						}
					},
					'ingredient' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $anchor_rgx) {
							return $+{ingredient}
						}
					},
					'overtime' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $anchor_rgx) {
							return $+{overtime} || 0;
						}
					},
					'id' => sub {
						$_->attr('href') =~ m/^.+id=(\d+)$/;
						$1;
					};
					process 'td:nth-child(2) span', 'season' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $span_rgx) {
							return $+{season};
						}
					},
					'episode' => sub {
						my $text = $_->as_trimmed_text();
						if ($text =~ $span_rgx) {
							return 0 + $+{episode};
						}
					};
				};
			};
			process 'div[align="center"] a', 'pages[]' => sub {
				my $pg = $_->attr('href'); #as_trimmed_text();
				#$pg =~ s/[^\d]+//g;
				return $pg =~ m/start=(\d+)/ ? $1 : '';
			}
		};
		
		my $scr_rslt = $scraper->scrape($content);
		#p($scr_rslt); exit(0);
		$results = {
			'entries' => $scr_rslt->{tables}->[3]->{entries},
			'max_page' => max( grep { $_ =~ m/^\d+$/ } @{ $scr_rslt->{pages} })
		};
	}
	
	return $results;
}

sub downloadFile {
	my $self = shift @_;
	my $id = shift @_;
	my $file = shift @_;
	
	#http://filehouse.ironcheffans.info/index.php?act=download&id=213
	my $params = {
		act => 'download',
		id => $id
	};
	my $url = $self->baseURL() . '/index.php?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	if ($page->{success}) {
		my $file_url = 0;
		if ($page->{content} =~ m/<meta http-equiv="refresh" content="2;url=(?<url>[^"]+)"/gism) {
			$file_url = $+{url};
		}
		
		if (! $file_url) {
			return 0;
		} else {
			my $cmd = 'wget';
			# --limit-rate 20k
			if ($self->max_bandwidth) {
				$cmd .= ' --limit-rate ' . $self->max_bandwidth;
			}
			
			$cmd .= " -c -O '$file' '$file_url'";
			#print $cmd;
			return `$cmd`;
		}
	}
	return 1;
}

sub getCategoryListing {
	my $self = shift @_;
	my $id = shift @_;
	
	#http://filehouse.ironcheffans.info/index.php?act=category&id=1
	my $params = {
		id => $id,
		start => 0
	};
	my $max_page = 1;
	
	my $results = [];
	
	do {
		$params->{start}++;
		my $pg = $self->fetchCategoryPage($params);
		if ($pg->{max_page} > $max_page) {
			$max_page = $pg->{max_page};
		}
		push @$results, @{ $pg->{entries} };
		#return $pg->{entries};
	} while ($params->{start} < $max_page);
	
	return $results;
}


1;