package Medac::Metadata::Source::Plex;
use lib '../../..';

use Moose;

extends 'Medac::Metadata::Source';

use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use URI::Escape;
use XML::Simple;

our $agents = {
	'com.plexapp.agents.thetvdb' => 'TV',
	'com.plexapp.agents.lastfm' => 'Music',
	'com.plexapp.agents.imdb' => 'Movie' #,
	#'com.plexapp.agents.none' => undefined
};

our $sections = [];

has 'hostname' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'protocol' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'http'
);

has 'port' => (
	'is' => 'rw',
	'isa' => 'Int',
	'default' => 32400
);

has 'username' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'password' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'maxage' => (
	'is' => 'rw',
	'isa' => 'Int',
	'default' => 10
);

has 'cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub {
		return new Medac::Cache('context'=>'Plex');
	}
);

has 'depth' => (
	'is' => 'rw',
	'isa' => 'Int',
	'default' => 0
);

sub baseURL {
	my $self = shift;
	return $self->protocol . '://' . $self->hostname. ':' . $self->port;
}

sub getNode {
	my $self = shift @_;
	my $name = shift @_;
	my $keys = shift @_;
	my $descend = shift @_;
	$descend = defined $descend ? $descend : 1;
	
	$self->depth(
		$self->depth + 1
	);
	
	my $url = $self->baseURL() . '/' . (join('/', @$keys));
	
	my $nodes = {};
	my $node = {
		name => $name,
		url => $url,
		obj => {},
		nodes => $nodes
	};
	
	my $cache_key = 'XML::' . $url;
	
	my $page = {};
	if (0 || $self->cache()->hit($cache_key)) {
		$page = $self->cache()->getVal($cache_key);
	} else {	
		$page = $self->pullURL($url);
		if ($page->{success}) { $self->cache->store($cache_key, $page); }
	} # cache?
	
	if ($page->{success}) {
		my $ref = XMLin($page->{content});
		
		if ($self->depth > 10) { exit 0; }
		
		if ($ref) {
			#print "$url\n"; #. Dumper($ref->{Directory}) . "\n-----------------------------------------------\n";
			if ($ref->{Directory}) {
				$node->{obj} = $ref->{Directory};
				foreach my $dkey (sort keys %{$ref->{Directory}}) {
					
					#print '' . ('--' x $self->depth()) . "> $dkey\n";
					#my $nurl = ($dkey !~ m/^\// ? $url . '/' : '') . $dkey;
					if ($dkey !~ m/^\//) {
						#push @$nodes, getNode($dkey, $nurl);
						push @$keys, $dkey;
						if ($descend > 0) {
							$nodes->{$dkey} = $self->getNode($dkey, $keys, $descend - 1);
						}
						pop @$keys;
					} # non-absolute path?
				} # foreach()
				$node->{nodes} = $nodes;
			} # Directory?
		} # parsed XML?
	} # success?
	
	
	$self->depth($self->depth - 1);
	
	return $node;
	
} # getNode()

sub getNodeGen {
	my $self = shift @_;
	my $opts = shift @_;
	my $keys = $opts->{keys} || [];
	my $decider = $opts->{decider} || sub { return 1; };
	my $drill = $opts->{drill} || [];
	
	$self->depth(
		$self->depth + 1
	);
	
	my $now = time;
	
	my $url = $self->baseURL() . '/' . (join('/', @$keys));
	
	my $nodes = [];
	
	my $cache_key = 'XML::' . $url;
	
	my $page = {};
	if ($self->cache()->hit($cache_key)) {
		$page = $self->cache()->getVal($cache_key);
	} else {	
		$page = $self->pullURL($url);
		if ($page->{success}) { $self->cache->store($cache_key, $page); }
	} # cache?
	
	if ($page->{success}) {
		my $ref = XMLin($page->{content});
		#print Dumper($ref);
		if ($self->depth > 10) { exit 0; }
		
		if ($ref) {
			if (my $obj = $self->objDrill($ref, ['Video'])) {
				foreach my $key (keys %{$obj}) {
					my $elem = $obj->{$key};
					if (&$decider($key, $elem)) {
						$elem->{key} = $key;
						$elem->{age} = $now - $elem->{addedAt};
					  push @$nodes, $elem;
					} # decider?
				} # foreach()
			} # section exists?
		} # parsed XML?
	} # success?
	
	
	$self->depth($self->depth - 1);
	
	return $nodes;
} # getNodeGen()

sub loadSections {
	my $self = shift @_;
	
	if (scalar @$sections < 1) {
		my $node = $self->getNode('Sections', ['library', 'sections'], 0);
		#my $sections = [];
		foreach my $sec_key (keys %{$node->{obj}}) {
			my $sec = $node->{obj}->{$sec_key};
			
			if (defined $agents->{$sec->{agent}}) {
				$sec->{key} = $sec_key;
				$sec->{mediaCategory} = $agents->{$sec->{agent}};
				push @$sections, $sec;
			}
		}
	}
		
	return $sections;
}

sub loadRecent {
	my $self = shift @_;
	my $section = shift @_;
	
	my $secs = $self->loadSections();
	my $now = time();
	my $max_sec = $now - $self->maxage();
	my $recent = $self->getNodeGen({
		'keys' => ['library', 'sections', $section, 'recentlyAdded'],
		'drill' => ['Video'],
		'decider' => sub {
			my $key = shift @_;
			my $obj = shift @_;
			if ($obj->{addedAt} >= $max_sec) {
				return 1;
			} else {
				return 0;
			}
		}
	});
	
	return $recent;
}

sub recentMovies {
	my $self = shift @_;
	my $secs = $self->loadSections();
	
	my $recent = [];
	foreach my $skey (@$secs) {
		#my $s = $secs->{$skey};
		my $s = $skey;
		if ($s->{mediaCategory} eq 'Movie') {
			$recent = $self->loadRecent($s->{key});
		}
	}
	
	return $recent;
}

sub recentEpisodes {
	my $self = shift @_;
	my $secs = $self->loadSections();
	my $recent = [];
	foreach my $skey (@$secs) {
		#my $s = $secs->{$skey};
		my $s = $skey;
		if ($s->{mediaCategory} eq 'TV') {
			$recent = $self->loadRecent($s->{key});
		}
	}
	
	return $recent;
}

sub nowPlaying {
	my $self = shift @_;

	my $now_playing = $self->getNodeGen({
		'keys' => ['status', 'sessions'],
		'decider' => sub {
			return 1;
		}
	});
	
	my $playing = [];
	
	foreach my $stream (@$now_playing) {
		my $nice_stream = {
			season => $stream->{parentIndex},
			episode => $stream->{index},
			year => $stream->{year},
			title => $stream->{title},
			show => $stream->{grandparentTitle},
			summary => $stream->{summary},
			duration => $stream->{duration} / 1000,
			viewed => ($stream->{duration} - $stream->{viewOffset}) / 1000,
			username => $stream->{User}->{title},
			user_id => $stream->{User}->{id},
			original => $stream
		};
		
		push @$playing, $nice_stream;
	}
	
	return Dumper($playing);
}

1;
