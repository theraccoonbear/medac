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
use Data::Printer;
use File::Slurp;
use Term::ReadKey;
use Time::HiRes qw(gettimeofday);
use POSIX;

use Number::Bytes::Human qw(format_bytes);
use Term::ANSIColor::Markup;


use Medac::Cache;
use Medac::Search::NZB::Unified;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Search::NZB::NZBPlanet;
use Medac::Downloader::Sabnzbd;
use Medac::Console::Menu;
use Medac::Metadata::Source::SickBeard;

my $cache = new Medac::Cache(context => 'nzb-srch');
my $previous_fh = select(STDOUT); $| = 1; select($previous_fh);

# Config
my $config_file = dirname(abs_path($0)) . "/test-config.json";

my $config = {};
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
} else {
	die "No config file specified";
}

my $omg = new Medac::Search::NZB::OMGWTFNZBS($config->{'omgwtfnzbs.me'});
my $nzbplanet = new Medac::Search::NZB::NZBPlanet($config->{'nzbplanet.net'});
my $searcher = new Medac::Search::NZB::Unified();
$searcher->addAgent($omg);
$searcher->addAgent($nzbplanet);
#p($searcher->search_agents);
#die;
my $sab = new Medac::Downloader::Sabnzbd($config->{'sabnzbd'});
my $sb = new Medac::Metadata::Source::SickBeard($config->{sickbeard});

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
	} elsif ($category eq 'movies') {
		$ret_val = movieSearch();
	} else {
		# Do something!?
	}
	return $ret_val;
}

sub manageSab() {

	ReadMode 4; # Turn off controls keys
	my $key;
	my $ticks = 0;
	my $tick_delay = $cache->retrieve('tick-delay') || 1;
	my $last_disp = 0;
	while (not defined ($key = ReadKey(-1))) {
		my $now = gettimeofday();
		if ($now - $last_disp > $tick_delay) {
			my $downloads = $sab->getStatus();
			print colorize("<white>SABNZBd Queue Status</white>") . "\n";
			print Medac::Console::Menu->hr() . "\n";
			my $max_len = $downloads->{meta}->{title_length};
			foreach my $dl (@{$downloads->{queue}}) {
				my $entry = '';
				$entry .= "    <red>" . ($dl->{status} eq 'Paused' ? '||' : '|>') . "<red> ";
				$entry .= "<cyan>" . sprintf('%-' . $max_len . 's', $dl->{name}) . "</cyan> ";
				$entry .= "<white>-</white> ";
				$entry .= "<yellow>" . sprintf('%-5s', format_bytes($dl->{bytes_downloaded})) . '</yellow>';
				$entry .= "<white>of</white> ";
				$entry .= "<yellow>" . sprintf('%-5s', format_bytes($dl->{bytes})) . '</yellow>';
				$entry .= "<white>(</white><yellow>" . sprintf('%0.2f', $dl->{percent_complete}) . '%</yellow><white>)</white>';
				print colorize($entry) . "\n";
			}
			print Medac::Console::Menu->hr() . "\n";
			print colorize("<white>Press any key to exit...</white>\n");
			$last_disp = $now;
			$ticks++;
		}
	}
	#print "Pressed: $key after $ticks ticks\n";
	print "\n\n\n";
	ReadMode 0;
} # manageSab

sub movieSearch {
	my $default_movie_name = $cache->retrieve('default-movie-name') || undef;
	my $default_movie_year = $cache->retrieve('default-movie-year') || undef;
	my $default_quality = $cache->retrieve('default-quality') || undef;
	
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
	
	my $movies = my $my_movies = $searcher->searchMovies({
		terms => $movie_name,
		filter => sub {
			my $n = shift @_;
			my $match = 1;
			
			if ($movie_year && $movie_year ne '.') {
				if ($movie_year =~ m/^(?<year>(19|20)\d{2})(?<modifier>[\+-])?$/) {
					if ($+{modifier} && $+{modifier} eq '+') {
						$match = $match && ($n->{year} eq '????' || $n->{year} >= $+{year});
					} elsif ($+{modifier} && $+{modifier} eq '-') {
						$match = $match && ($n->{year} eq '????' || $n->{year} <= $+{year});
					}
				} else {
					$match = $match && $n->{year} eq $movie_year;
				}
			}
			
			if ($quality && $quality =~ m/^.+$/) { $match = $match && $n->{video_quality} =~ m/($quality)/gi; }
			
			return $match;
		}
	});
	
	if (scalar @$movies >= 1) {
		$result->{results} = $movies;
	}
	
	return $result;
	#return $shows;
} # movieSearch()

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
	
	my $shows = my $my_content = $searcher->searchTV({
		terms => $show_name,
		season => $season,
		episode => $episode,
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
} # tvSearch()

sub listSickbeardShows {
	print Medac::Console::Menu->hr() . "\n";
	my $shows = $sb->managedShows();
	if ($shows->{success}) {
		foreach my $show (@{$shows->{shows}}) {			
			my $entry = '';
			$entry .= ($show->{airing} ? ' <green>ON-AIR</green>' : '<red>OFF-AIR</red>') . '  ';
			$entry .= ($show->{paused} ? "<red>||</red>" : "<green>|></green>") . '  ';
			$entry .= '<yellow>' . sprintf('%10s', $show->{next_air_date}) . '</yellow> ';
			$entry .= '<cyan>' . sprintf('%-' . $shows->{longest} . 's', $show->{name}) . '</cyan> ';
			$entry .= '<white>' . $show->{downloaded} . '/' . $show->{count} . ' (' . sprintf('%0.2f', $show->{dl_percent}) . '%)</white> ';
			$entry .= "\n";
			print colorize($entry);
		}
	}
}

sub addShow {
	my $term = prompt("New Show Name?");
	my $results = $sb->search($term);
	my $add_menu = new Medac::Console::Menu('title' => 'Select Show');
	
	my $root_dirs = $sb->rootDirs();
	my $def_dir = '';
	foreach my $dir (@{ $root_dirs->{dirs} }) {
		if ($dir->{default}) {
			$def_dir = $dir->{location};
			last;
		}
	}
	
	my $i = 1;
	my $resp = '';
	my $added = 0;
	foreach my $show (@{ $results->{results} }) {
		$add_menu->addItem(new Medac::Console::Menu::Item(
			key => $i++,
			label => colorize('<white>' . $show->{name} . '</white> <cyan>(</cyan><yellow>First Aired: ' . $show->{first_aired} . '</yellow><cyan>)</cyan>'),
			action => sub {
				my $location = prompt("Location <cyan>(</cyan><yellow>Enter for:</yellow> <white>$def_dir</white><cyan>)</cyan>");
				if ($location eq '') {
					$location = $def_dir;
				}
				
				my $wanted = prompt("Find all episodes <cyan>(</cyan><yellow>y/N<cyan>)</cyan>");
				my $params = {};
				if (lc($wanted) eq 'y') {
					$params->{status} = 'wanted';
				}
				
				my $add_result = $sb->addShow($show->{tvdbid}, $location, $params);
				$added = 1;
			}
		));
	}
	
	$add_menu->addItem(new Medac::Console::Menu::Item(
		key => 'X',
		label => 'Cancel Add'
	));
	
	
	while (!$added && $resp ne 'X') {
		$resp = uc($add_menu->display());
	}
}

sub manageSickbeard {
	my $sb_menu = new Medac::Console::Menu(title => 'Sickbeard Console');
	
	$sb_menu->addItem(new Medac::Console::Menu::Item(
		key => 'A',
		label => 'Add New Show',
		action => \&addShow
	));
	
	$sb_menu->addItem(new Medac::Console::Menu::Item(
		key => 'L',
		label => 'List Shows',
		action => \&listSickbeardShows
	));
	
	$sb_menu->addItem(new Medac::Console::Menu::Item(
		key => 'X',
		label => 'Exit Sickbeard Console'
	));
	
	my $resp = '';
	while ($resp ne 'X') {
		$resp = uc($sb_menu->display());
	}
	
	
} # manageSickbeard


my $resp = '';
my $queued = $cache->retrieve('queue') || {};




my $my_content;

while ($resp !~ m/^X$/i) {
	my $main_menu = new Medac::Console::Menu(title => 'Actions:');
	$main_menu->addItem(new Medac::Console::Menu::Item(
		key => 'S',
		label => 'Search'
	));
	
	$main_menu->addItem(new Medac::Console::Menu::Item(
		key => 'C',
		label => colorize('Change SABNZBd Download Category (current: <yellow>' . $category . '</yellow>)'),
		action => \&setCategory
	));
	
	$main_menu->addItem(new Medac::Console::Menu::Item(
		key => 'V',
		label => 'Manage SABNZBd',
		action => \&manageSab
	));
			
	$main_menu->addItem(new Medac::Console::Menu::Item(
		key => 'B',
		label => 'Manage Sickbeard',
		action => \&manageSickbeard
	));																							 

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
				my $provider = $content->{provider};
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
					$entry_str .= "<cyan>$release</cyan> [<magenta>$provider</magenta>]";
				} elsif ($category eq 'movies') {
					$entry_str .= "<yellow>$year</yellow>";
					$entry_str .= ' - ';
					$entry_str .= "<blue>$quality</blue>";
					$entry_str .= ' - ';
					$entry_str .= "<yellow>$size</yellow>";
					$entry_str .= ' - ';
					$entry_str .= "<red>$daysOld day(s) old</red>";
					$entry_str .= ' - ';
					$entry_str .= "<cyan>$release</cyan> [<magenta>$provider</magenta>]";
				}
				my $label = colorize($entry_str);
				$choose_menu->addItem(
					new Medac::Console::Menu::Item(
						key => (scalar(@{$my_content->{results}}) - $idx) + 1,
						label => $label,
						prefix => $queued->{$content->{getnzb}} ? '*' : '',
						action => sub {
							if ($sab->queueDownload($content->{getnzb}, $content->{release}, $category)) {
								$queued->{$content->{getnzb}} = $content;
								$cache->store('queue', $queued);
								print "Queued in sabnzbd\n";
							} else {
								print "Couldn't be queued!\n";
							}
						}
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
		}
	}
}

print "\n\nGoodbye!\n";
exit(0);