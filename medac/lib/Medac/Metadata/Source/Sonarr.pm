package Medac::Metadata::Source::Sonarr;
use lib '../../..';

use Moose;

extends 'Medac::Metadata::Source';

use Web::Scraper;
use HTTP::Cookies;
use Data::Printer;
use Mojo::DOM;
use Medac::Cache;
use Time::Local;
use URI::Escape;
use JSON::XS;
use XML::Simple;
use Digest::MD5 qw(md5);

binmode(STDOUT, ":utf8");

our $sections = [];


our $init_quality = {map {$_ => 1} qw(sdtv sddvd hdtv rawhdtv fullhdtv hdwebdl fullhdwebdl hdbluray fullhdbluray unknown)};
our $arch_quality = {map {$_ => 1} qw(sddvd hdtv rawhdtv fullhdtv hdwebdl fullhdwebdl hdbluray fullhdbluray)};
our $statuses = {map {$_ => 1} qw(wanted skipped archived ignored)};

has 'protocol' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'http'
);

has 'hostname' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'port' => (
	'is' => 'rw',
	'isa' => 'Int',
	'default' => 8081
);

has 'username' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'password' => (
	'is' => 'rw',
	'isa' => 'Str'
);

has 'apiKey' => (
	'is' => 'rw',
	'isa' => 'Str'
);


has 'cache' => (
	'is' => 'rw',
	'isa' => 'Medac::Cache',
	'default' => sub {
		return new Medac::Cache('context'=>'CouchPotato');
	}
);

sub baseURL {
	my $self = shift;
	return $self->protocol . '://' . $self->hostname. ':' . $self->port . '/api/' . $self->apiKey;
}

sub getEpisodes {
	my $self = shift @_;
	my $tvdb_id = shift @_;
	my $params = {
		cmd => 'show.seasons',
		tvdbid => $tvdb_id
	};
	
	my $url = $self->baseURL() . '?' . $self->encodeParams($params);
	my $page = $self->pullURL($url);
	my $data = decode_json($page->{content});

	my $episodes = [];
	my $total_cnt = 0;
	my $dl_cnt = 0;
	if (lc($data->{result}) eq 'success') {
		foreach my $season_num (keys %{ $data->{'data'} }) {
			if ($season_num != 0) {
				my $season = $data->{data}->{$season_num};
				foreach my $ep_num (keys %{ $season }) {
					my $e = $season->{$ep_num};
					my $aired = '';
					if ($e->{airdate}) {
						my ($year, $mon, $mday) = split(/-/, $e->{airdate});
						$mon--;
						my $air_date = timelocal(0, 0, 0, $mday, $mon, $year);
						$aired = $air_date <= time();
					}
					
					my $ep = {
						season => $season_num,
						episode => $ep_num,
						air_date => $e->{airdate},
						aired => $aired,
						title => $e->{name},
						downloaded => $e->{status} eq 'Downloaded',
						quality => $e->{quality}
					};
					
					$total_cnt += $aired ? 1 : 0;
					$dl_cnt += $ep->{downloaded} ? 1 : 0;
					push @$episodes, $ep;
				}
			}
		}
		$episodes = [sort { $a->{season} <=> $b->{season} || $a->{episode} <=> $b->{episode} } @$episodes];
	}
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		count => $total_cnt,
		downloaded => $dl_cnt,
		dl_percent => ($total_cnt > 0 ? (($dl_cnt / $total_cnt) * 100) : 100),
		episodes => $episodes
	};
}

sub getShow {
	my $self = shift @_;
	my $tvdbid = shift @_;
	my $params = {
		cmd => 'show',
		tvdbid => $tvdbid
	};
	my $url = $self->baseURL() . '?' . $self->encodeParams($params);
	my $page = $self->pullURL($url);
	my $data = decode_json($page->{content});
	my $show = {};
	if (lc($data->{result}) eq 'success') {
		$show = $data->{data};
	}
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		show => $show
	};
}

sub managedShows {
	my $self = shift @_;
	my $params = {
		cmd => 'shows'
	};
	my $url = $self->baseURL(). '?' .  $self->encodeParams($params);
	my $page = $self->pullURL($url);
	my $data = decode_json($page->{content});
	my $shows = [];
	my $long_title = '';
	if (lc($data->{result}) eq 'success') {
		foreach my $show_key (keys %{ $data->{data}}) {
			my $s = $data->{data}->{$show_key};
			my $show_detail = $self->getShow($s->{tvdbid});
			my $episodes = $self->getEpisodes($s->{tvdbid});
			if ($show_detail->{success}) {
				$show_detail = $show_detail->{show};
			}
			my $new_show = {
				id => $show_key,
				name => $show_detail->{show_name},
				airing => lc($show_detail->{status}) eq 'continuing' ? 1 : 0,
				location => $show_detail->{location},
				next_air_date => $s->{next_ep_airdate},
				airs => $show_detail->{airs},
				network => $show_detail->{network},
				quality => $show_detail->{quality},
				paused => $show_detail->{paused} ? 1 : 0,
				seasons => $show_detail->{season_list},
				tvdb_id => $s->{tvdbid},
				tvrage_id => $s->{tvrage_id},
				episodes => $episodes->{episodes},
				count => $episodes->{count},
				downloaded => $episodes->{downloaded},
				dl_percent => $episodes->{dl_percent}
			};
			
			if (length($show_detail->{show_name}) > length($long_title)) {
				$long_title = $show_detail->{show_name};
			}
			
			
			push @$shows, $new_show;
		}
		
		$shows = [sort { lc($a->{name}) cmp lc($b->{name}) } @$shows];
	}
	
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		longest => length($long_title),
		shows => $shows
	};
}

sub rootDirs {
	my $self = shift @_;
	
	my $params = {
		cmd => 'sb.getrootdirs'
	};
	
	my $url = $self->baseURL() . '?' . $self->encodeParams($params);
	my $page = $self->pullURL($url);
		
	my $data = decode_json($page->{content});
	my $results = [];
	if (lc($data->{result}) eq 'success') {
		$results = $data->{data};
	}
	
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		dirs => $results
	};
	
}

sub search {
	my $self = shift @_;
	my $name = shift @_;
	my $is_tvdb_id = shift @_;
	
	my $params = {
		cmd => 'sb.searchtvdb'
	};
	
	if ($is_tvdb_id) {
		$params->{tvdbid} = $name;
	} else {
		$params->{name} = $name;
	}
	
	my $url = $self->baseURL() . '?' . $self->encodeParams($params);
	my $page = $self->pullURL($url);
	
	
	my $data = decode_json($page->{content});
	my $results = [];
	if (lc($data->{result}) eq 'success') {
		$results = $data->{data}->{results};
	}
	
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		results => $results
	};
}

sub addShow {
	my $self = shift @_;
	my $tvdb_id = shift @_;
	my $location = shift @_;
	my $options = shift @_;
	
	my $params = {
		cmd => 'show.addnew',
		tvdbid => $tvdb_id
	};
	
	#my $root_dirs = $self->rootDirs();
	#p($root_dirs);
	
	if ($options->{initial} && $init_quality->{$options->{initial}}) { $params->{initial} = $options->{initial}; }
	if ($options->{archive} && $arch_quality->{$options->{archive}}) { $params->{archive} = $options->{archive}; }
	if ($options->{status} && $statuses->{$options->{status}}) { $params->{status} = $options->{status}; }
	
	
	my $url = $self->baseURL() . '?' . $self->encodeParams($params);
	my $page = $self->pullURL($url);
	my $data = decode_json($page->{content});
	#p($data);
	return {
		success => lc($data->{result}) eq 'success',
		message => $data->{message},
		results => $data->{data}
	};
	
}


1;
