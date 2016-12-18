package Medac::Search::NZB::Womble;
use lib '../../..';

use Moose;

extends 'Medac::Search::NZB';

use IO::Socket::SSL qw();
use WWW::Mechanize qw();
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use JSON::XS;
use URI::Escape;
use Web::Scraper;

has '+hostname' => (
	is => 'rw',
	isa => 'Str',
	default => 'www.newshost.co.za'
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
	my $section = shift @_ || 'TV';
	my $retention = shift @_ || 1600;
	
	my $params = {
		s => $terms
	};
	
	my $url = $self->baseURL() . '/?' . $self->encodeParams($params);
	
	my $page = $self->pullURL($url);
	
	my $results = [];
	
	if ($page->{success}) {
		my $content = $page->{content};
		
		my $scraper = scraper {
			process 'tr', 'entries[]' => scraper {
				process 'td:nth-child(1)', 'released' => 'TEXT';
				process 'td:nth-child(2)', 'size' => 'TEXT';
				process 'td:nth-child(3)', 'section' => 'TEXT';
				process 'td:nth-child(4) a:nth-child(1)', 'nzb' => '@href';
				process 'td:nth-child(4) a:nth-child(2)', 'nfo' => '@href';
				process 'td:nth-child(5)', 'days_old' => 'TEXT';
				process 'td:nth-child(6)', 'release' => 'TEXT';
			};
		};
		
		my $scr_rslt = $scraper->scrape($content);
		
		foreach my $nzb (@{$scr_rslt->{entries}}) {
			if ($nzb->{nzb}) {
				$nzb->{nzb} = $self->baseURL() . '/' . $nzb->{nzb};
				if ($nzb->{nfo}) {
					$nzb->{nfo} = $self->baseURL() . '/' . $nzb->{nfo};
				}
				($nzb->{section}, $nzb->{subsection}) = split(/-/, $nzb->{section} . '-');
				$nzb->{usenetage} = 0;
				if ($nzb->{days_old} =~ m/^(?<num>[\d,]+)(?<unit>[dhm])$/) {
					my $num = $+{num};
					my $unit = $+{unit};
					$num =~ s/[^\d]+//;
					if ($unit eq 'd') {
						$num = $num * 60 * 60 * 24;
					} elsif ($unit eq 'h') {
						$num = $num * 60 * 24;
					} else {
						$num = $num * 60;
					}
					$nzb->{usenetage} = $num;
				}
				
				
				$nzb = $self->parseRelease($nzb, {provider => 'Womble'});
				push @$results, $nzb;
			}
		}
		
	}
	
	
	return $results;
} # search()

1;