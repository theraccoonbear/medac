#!/usr/bin/perl
use strict;
use warnings;

#use Cwd 'abs_path';
use FindBin;
use lib "$FindBin::Bin/..";

use JSON::XS;
use Getopt::Long;

use Data::Dumper;
use File::Slurp;

use POSIX;

use Number::Bytes::Human qw(format_bytes);

use Medac::Cache;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Downloader::Sabnzbd;

my $cache = new Medac::Cache(context => 'nzb-srch');

my $previous_fh = select(STDOUT); $| = 1; select($previous_fh);

# Config

my $config_file = 'test-config.json';

my $config = {};
my $host_name = 0;
my $port = 32400;
my $username = 0;
my $password = 0;
my $script_started = time();
my $action_started;

GetOptions(
	'config=s' => \$config_file
);

if ($config_file && -f $config_file) {
	my $file_data = read_file($config_file);
	$config = decode_json($file_data);
	
	$host_name = $config->{hostname} || $host_name;
	$port =  $config->{port} || $port;
	$username = $config->{username} || $username;
	$password = $config->{password} || $password;
} else {
	die "No config file specified";
}

my $omg = new Medac::Search::NZB::OMGWTFNZBS($config->{'omgwtfnzbs.org'});
my $sab = new Medac::Downloader::Sabnzbd($config->{'sabnzbd'});

sub commify {
   my $input = shift;
   $input = reverse $input;
   $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return reverse $input;
}

sub prompt {
	my $msg = shift @_;
	my $acceptable = shift @_ || '.*?';
	my $is_acceptable = 0;
	my $answer = '';
	while (!$is_acceptable) {
		print "$msg ";
		$answer = <STDIN>;
		chomp($answer);
		$is_acceptable = ($answer =~ m/$acceptable/gi);
	}
	return $answer;
} # prompt()

sub startSearch {
	
	my $default_show_name = $cache->retrieve('default-show-name');
	my $default_season = $cache->retrieve('default-season');
	my $default_episode = $cache->retrieve('default-episode');
	my $default_quality = $cache->retrieve('default-quality');
	
	my $show_name = prompt("Show name [enter for \"" . ($default_show_name || 'no name') . "\"]?");
	my $season = prompt("Season No. [enter for \"" . ($default_season || 'no season') . "\"]?");
	my $episode = prompt("Episode No. [enter for \"" . ($default_episode || 'no episode') . "\"]?");
	my $quality = prompt("Quality [enter for \"" . ($default_quality || 'no quality') . "\", e.g. 720p, HDTV|SDTV, etc]?");
	
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
	
	my $shows = my $my_shows = $omg->searchTV({
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

while ($resp !~ m/^X$/i) {
		
	my $my_shows = startSearch();
	$resp = '';
	while ($resp !~ m/^X$/i) {
		my $menu = "Choose NZB?\n";
		my $idx = 0;
		my $entries = {};
		my $opts = ();
		
		foreach my $show (sort {$b->{usenetage} <=> $a->{usenetage}} @{$my_shows->{results}}) {
			my $season = sprintf('%02d', $show->{season});
			my $episode = sprintf('%02d', $show->{episode});
			my $release = $show->{release};
			my $quality = sprintf('%-5s', $show->{video_quality});
			my $size = sprintf('%5s', format_bytes($show->{sizebytes}));
			my $daysOld = commify(ceil((time - $show->{usenetage}) / 60 / 60 / 24));
			$idx++;
			my $didx = sprintf('%2s', $idx);
			$show->{fmtseason} = $season;
			$show->{fmtepisode} = $episode;
			$entries->{$idx} = $show;
			push @$opts, $idx;
			my $leading = $queued->{$show->{getnzb}} ? '*' : ' ';
			$menu .= $leading . "   $didx) s${season}e${episode} - $quality - $size - $daysOld day(s) old - $release\n";
		}
		push @$opts, 'X'; push @$opts, 'x';
		$menu .= "     X) Exit\n\n* indicates NZB has been queued in Sab.\n\nQueue which NZB in Sab:";
		
		$resp = prompt($menu, '(' . join('|', @$opts) . ')');
		if ($resp =~ m/^\d+$/) {
			my $show = $entries->{$resp};
			if ($sab->queueDownload($show->{getnzb}, $show->{release}, 'tv')) {
				$queued->{$show->{getnzb}} = $show;
				$cache->store('queue', $queued);
				print "Queued in sabnzbd\n";
			} else {
				print "Couldn't be queued!\n";
			}
		}
	}
	
	$resp = prompt("Actions:\n    S) Search\n    X) Exit\n\nAction?", '^[SsXx]$');
}

print "\n\nGoodbye!\n";
exit(0);