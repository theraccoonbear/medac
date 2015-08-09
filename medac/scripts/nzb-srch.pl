#!/usr/bin/perl
use strict;
use warnings;

#use Cwd 'abs_path';
use FindBin;
use Cwd 'abs_path';
use File::Basename;

#use lib "$FindBin::Bin/..";

use lib dirname(abs_path($0)) . '/..';

use JSON::XS;
use Getopt::Long;

use Data::Dumper;
use File::Slurp;

use POSIX;

use Number::Bytes::Human qw(format_bytes);
use Term::ANSIColor::Markup;


use Medac::Cache;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Downloader::Sabnzbd;
use Medac::Console::Menu;

my $cache = new Medac::Cache(context => 'nzb-srch');
my $previous_fh = select(STDOUT); $| = 1; select($previous_fh);

# Config
my $config_file = dirname(abs_path($0)) . "/test-config.json";

my $config = {};
#my $host_name = 0;
#my $port = 32400;
#my $username = 0;
#my $password = 0;
my $script_started = time();
my $action_started;
my $category = 'tv';

my $parser = new Term::ANSIColor::Markup();

sub colorize {
	my $text = shift @_;
	return Term::ANSIColor::Markup->colorize($text);
}

GetOptions(
	'config=s' => \$config_file
);

if ($config_file && -f $config_file) {
	my $file_data = read_file($config_file);
	$config = decode_json($file_data);
	
	#$host_name = $config->{hostname} || $host_name;
	#$port =  $config->{port} || $port;
	#$username = $config->{username} || $username;
	#$password = $config->{password} || $password;
} else {
	die "No config file specified";
}

my $omg = new Medac::Search::NZB::OMGWTFNZBS($config->{'omgwtfnzbs.org'});
my $sab = new Medac::Downloader::Sabnzbd($config->{'sabnzbd'});

sub commafy {
   my $input = shift;
   my $output = reverse $input;
   $output =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	 $output = reverse $output;
   return $output;
}

sub prompt {
	my $msg = colorize(shift @_);
	my $acceptable = shift @_ || '.*?';
	my $is_acceptable = 0;
	my $answer = '';
	while (!$is_acceptable) {
		print "$msg ";
		$answer = <STDIN>;
		chomp($answer);
		$is_acceptable = ($answer =~ m/$acceptable/gi);
	}
	return lc($answer);
} # prompt()

sub setCategory {
	my $cat_menu = new Medac::Console::Menu(title => 'Set Download Category (current: ' . $category . ')');
	my $cats = $sab->getCategories();
	my $idx = 0;
	foreach my $cat (sort @$cats) {
		if ($cat =~ m/^[A-Za-z]+$/) {
			$idx++;
			$cat_menu->addItem(new Medac::Console::Menu::Item(key => $idx, label => $cat, returns => $cat));
		}
	}
	my $new_cat = $cat_menu->display();
	if ($new_cat ne 'x') {
		$category = $new_cat;
	}
}


sub startSearch {
	my $ret_val = {};
	if ($category eq 'tv') {
		$ret_val = tvSearch();
	} elsif ($category eq 'movie') {
		$ret_val = movieSearch();
	}
	
}

sub movieSearch {
	my $default_movie_name = $cache->retrieve('default-movie-name');
	my $default_movie_year = $cache->retrieve('default-movie-year');
	my $default_quality = $cache->retrieve('default-quality');
	
	my $movie_name = prompt("Movie <yellow>name</yellow> [enter for <cyan>\"</cyan><white>" . ($default_movie_name || 'no name') . "</white><cyan>\"</cyan>]?");
	my $movie_year = prompt("Movie <yellow>year</yellow> [enter for <cyan>\"</cyan><white>" . ($default_movie_year || 'any year') . "</white><cyan>\"</cyan>]?");
	my $quality = prompt("Movie <yellow>quality</yellow> [enter for <cyan>\"</cyan><white>" . ($default_quality || 'any quality') . "</white><cyan>\"</cyan>, e.g. 720p, HDTV|SDTV, etc]?");
	
	$movie_name = $movie_name =~ m/.+/ ? $movie_name : $default_movie_name;
	$movie_year = $movie_year =~ m/.+[\+-]?/ ? $movie_year : $default_movie_year;
	$quality = $quality=~ m/.+/ ? $quality: $default_quality;
	
	$cache->store('default-movie-name', $movie_name);
	$cache->store('default-movie-year', $movie_year);
	$cache->store('default-quality', $quality);
	
	my $result = {
		movie_name => $movie_name,
		movie_year => $movie_year,
		quality => $quality,
		results => []
	};
	
	my $movies = my $my_movies = $omg->searchMovies({
		terms => $movie_name,
		filter => sub {
			my $n = shift @_;
			my $match = 1;
			
			if ($movie_year =~ m/^(?<year>(19|20)\d{2})(?<modifier>[\+-])?$/) {
				if ($+{modifier} eq '+') {
					$match = $match && ($n->{year} eq '????' || $n->{year} >= $+{year});
				} elsif ($+{modifier} eq '-') {
					$match = $match && ($n->{year} eq '????' || $n->{year} <= $+{year});
				}
			} else {
				$match = $match && $n->{year} eq $movie_year;
			}
			if ($quality =~ m/^.+$/) { $match = $match && $n->{video_quality} =~ m/($quality)/gi; }
			
			return $match;
		}
	});
	
	if (scalar @$movies >= 1) {
		$result->{results} = $movies;
	}
	
	return $result;
	#return $shows;
} # startSearch()

sub tvSearch {
	my $default_show_name = $cache->retrieve('default-show-name');
	my $default_season = $cache->retrieve('default-season');
	my $default_episode = $cache->retrieve('default-episode');
	my $default_quality = $cache->retrieve('default-quality');
	
	my $show_name = prompt("Show <yellow>Name</yellow> [enter for <cyan>\"</cyan><white>" . ($default_show_name || 'no name') . "</white><cyan>\"</cyan>]?");
	my $season = prompt("Show <yellow>Season No.</yellow> [enter for <cyan>\"</cyan><white>" . ($default_season || 'any season') . "</white><cyan>\"</cyan>]?");
	my $episode = prompt("Show <yellow>Episode No.</yellow> [enter for <cyan>\"</cyan><white>" . ($default_episode || 'any episode') . "</white><cyan>\"</cyan>]?");
	my $quality = prompt("Show <yellow>Quality</yellow> [enter for <cyan>\"</cyan><white>" . ($default_quality || 'any quality') . "</white><cyan>\"</cyan>, e.g. 720p, HDTV|SDTV, etc]?");
	
	$show_name = $show_name =~ m/.+/ ? $show_name : $default_show_name;
	$season = $season =~ m/.+/ ? $season : $default_season;
	$episode = $episode =~ m/.+/ ? $episode : $default_episode;
	$quality = $quality=~ m/.+/ ? $quality: $default_quality;
	
	$cache->store('default-show-name', $show_name);
	$cache->store('default-season', $season);
	$cache->store('default-episode', $episode);
	$cache->store('default-quality', $quality);
	
	my $result = {
		show => $show_name,
		season => $season,
		episode => $episode,
		quality => $quality,
		results => []
	};
	
	my $shows = my $my_content = $omg->searchTV({
		terms => $show_name,
		filter => sub {
			my $n = shift @_;
			my $match = 1;
			
			if ($season =~ m/^\d+$/) { $match = $match && $n->{season} == $season; }
			if ($episode =~ m/^\d+$/) { $match = $match && $n->{episode} == $episode; }
			if ($quality =~ m/^.+$/) { $match = $match && $n->{video_quality} =~ m/($quality)/gi; }
			
			return $match;
		}
	});
	
	if (scalar @$shows >= 1) {
		$result->{results} = $shows;
	}
	
	return $result;
	#return $shows;
} # startSearch()


my $resp = '';
my $queued = $cache->retrieve('queue') || {};




my $my_content;

while ($resp !~ m/^X$/i) {
	my $main_menu = new Medac::Console::Menu(title => 'Actions:');
	$main_menu->addItem(new Medac::Console::Menu::Item(key => 'S', label => 'Search'));
	$main_menu->addItem(new Medac::Console::Menu::Item(key => 'C', label => colorize('Change SABNZBd Download Category (current: <yellow>' . $category . '</yellow>)')));

	$resp = $main_menu->display();
	my $show_resp = '';
	if ($resp eq 's') {
		$show_resp = '';
		$my_content = startSearch();
		my $unfiltered = {%$my_content};
		my $filters = [];
		my $filtering = 0;
		while ($show_resp !~ m/^X$/i) {
			my $choose_menu = new Medac::Console::Menu(title => 'Choose NZB', post => '* indicates NZB has been queued in Sab.');
			my $idx = 0;
			my $entries = {};
			my $opts = ();
			
			foreach my $content (sort {$a->{usenetage} <=> $b->{usenetage}} @{$my_content->{results}}) {
				my $season = sprintf('%02d', $content->{season});
				my $episode = sprintf('%02d', $content->{episode});
				my $year = $content->{year} =~ m/^\d{4}$/ ? sprintf('%04d', $content->{year}) : '    ';
				my $release = $content->{release};
				my $quality = sprintf('%-5s', $content->{video_quality});
				my $size = sprintf('%5s', format_bytes($content->{sizebytes}));
				#my $daysOld = sprintf('%4s', commafy(ceil((time - $content->{usenetage}) / 60 / 60 / 24)));
				my $daysOld = commafy(ceil((time - $content->{usenetage}) / 60 / 60 / 24));
				$daysOld = (' ' x (4 - length($daysOld))) . $daysOld;
				$idx++;
				my $didx = sprintf('%2s', $idx);
				$content->{fmtseason} = $season;
				$content->{fmtepisode} = $episode;
				$entries->{$idx} = $content;
				my $entry_str = '';
				
				if ($category eq 'tv') {
					$entry_str .= "<yellow>s</yellow><white>${season}</white><yellow>e</yellow><white>${episode}</white>";
					$entry_str .= ' - ';
					$entry_str .= "<blue>$quality</blue>";
					$entry_str .= ' - ';
					$entry_str .= "<yellow>$size</yellow>";
					$entry_str .= ' - ';
					$entry_str .= "<red>$daysOld day(s) old</red>";
					$entry_str .= ' - ';
					$entry_str .= "<cyan>$release</cyan>";
				} elsif ($category eq 'movie') {
					$entry_str .= "<yellow>$year</yellow>";
					$entry_str .= ' - ';
					$entry_str .= "<blue>$quality</blue>";
					$entry_str .= ' - ';
					$entry_str .= "<yellow>$size</yellow>";
					$entry_str .= ' - ';
					$entry_str .= "<red>$daysOld day(s) old</red>";
					$entry_str .= ' - ';
					$entry_str .= "<cyan>$release</cyan>";
				}
				my $label = colorize($entry_str);
				$choose_menu->addItem(
					new Medac::Console::Menu::Item(
						key => (scalar(@{$my_content->{results}}) - $idx) + 1,
						label => $label,
						prefix => $queued->{$content->{getnzb}} ? '*' : ''
					)
				);
			}
			
			$choose_menu->addItem(
				new Medac::Console::Menu::Item(
					key => 'F',
					label => 'Filter Results',
					action => sub {
								print "Filter Regex: ";
								my $rgx_filter = <STDIN>;
								chomp($rgx_filter);
								push @$filters, $rgx_filter;
								my $new_content = [];
								foreach my $c (@{$my_content->{results}}) {
												if ($c->{release} =~ /$rgx_filter/i) {
																push @$new_content, $c;
												}
												
								}
								$filtering = 1;
								$my_content->{results} = $new_content;
					}
				)
			);
			
			if ($filtering) {
				$choose_menu->addItem(
				new Medac::Console::Menu::Item(
					key => 'C',
					label => colorize('Clear Filters ("<yellow>' . join('</yellow>", "<yellow>', @$filters) . '</yellow>")'),
					action => sub {
								$filtering = 0;
								$filters = [];
								$my_content->{results} = $unfiltered->{results};
					}
				)
			);
			}
			
			
			$show_resp = $choose_menu->display();
			if ($show_resp =~ m/^\d+$/) {
				my $show = $entries->{$show_resp};
				if ($sab->queueDownload($show->{getnzb}, $show->{release}, $category)) {
					$queued->{$show->{getnzb}} = $show;
					$cache->store('queue', $queued);
					print "Queued in sabnzbd\n";
				} else {
					print "Couldn't be queued!\n";
				}
			}
		}
	} elsif ($resp eq 'c') {
		setCategory();
	}
}

print "\n\nGoodbye!\n";
exit(0);