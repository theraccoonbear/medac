#!/usr/bin/perl
use strict;
use warnings;

use Cwd 'abs_path';

use FindBin;
use lib "$FindBin::Bin/..";

use Web::Scraper;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Entities;
use Time::Local;
use Data::Dumper;
use WWW::Mechanize;
use Mojo::DOM;
use JSON::XS;
use Time::HiRes qw(usleep);
use URI::Escape;
use Getopt::Long;
use DateTime;
use Medac::Metadata::Source::Plex;

#use DateTime::Format::Natural;
#use Time::Duration;
#use Email::Sender::Simple qw(sendmail);
#use XML::Simple;
#use Cache::FileCache;

#my $cache = new Cache::FileCache({
#	'namespace' => 'Plex',
#	'default_expires_in' => 600
#});

#my $parser = DateTime::Format::Natural->new;

my $now = time();

# Disable output buffering
select((select(STDOUT), $|=1)[0]);

my $ua_string = "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.A.B.C Safari/525.13";



my $max_days = 7;
my $host_name = 0;
my $port = 32400;
my $sender = 0;
my $recip = 0;
my $username = 0;
my $password = 0;

GetOptions(
	'm|max|maxdays=i' => \$max_days,
	'h|host|hostname=s' => \$host_name,
	'p|port' => \$port,
	'u|user|username=s' => \$username,
	'pass|password=s' => \$password
);



if (!$host_name) {
	print "No hostname\n";
	exit(0);
}

if (!$username) {
	print "No username\n";
	exit(0);
}

if (!$password) {
	print "Password: ";
	my $password = <STDIN>;
	chomp($password);
}


if ($max_days < 1) {
	$max_days = 1;
}

my $plex = new Medac::Metadata::Source::Plex(
	hostname => $host_name,
	port => $port,
	username => $username,
	password => $password,
	maxage => $max_days * 60 * 60 * 24
);

sub rule {
	print "\n\n~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=~=\n\n";
}

rule();

print "Recent Movies:\n\n";

my $recent_movies = $plex->recentMovies();
if (scalar @$recent_movies > 0) {
	
	foreach my $movie (sort { $a->{addedAt} <=> $b->{addedAt} } @$recent_movies) {
		$movie->{shortSummary} = length $movie->{summary} > 100 ? substr($movie->{summary}, 0, 100) : $movie->{summary};
		#my $dur = $plex->objDrill($movie, ['Media','Part','duration']);
		#$movie->{duration} = $dur && ($dur = DateTime->from_epoch(epoch => $dur)) ? ($dur->hour() . ' hour' . ($dur->hour() == 1 ? '' : 's') . ' ' . $dur->minute() . ' minute' . ($dur->minute() == 1 ? '' : 's')): 'UNKNOWN';
		#print "  * $movie->{title} ($movie->{year}) [$movie->{duration}] -- $movie->{shortSummary}\n";
		print "  * \"$movie->{title}\" ($movie->{year}) -- $movie->{shortSummary}\n";
		#print Dumper($movie);
	}
} else {
	print "  * No recent movies\n";
}

rule();

print "Recent TV Episodes:\n\n";

my $recent_episodes = $plex->recentEpisodes();
if (scalar @$recent_episodes > 0) {
	foreach my $episode (sort { $a->{addedAt} <=> $b->{addedAt} } @{$recent_episodes}) {
		$episode->{season} = sprintf('%02d', $episode->{parentIndex});
		$episode->{episode} = sprintf('%02d', $episode->{index});
		print "  * \"$episode->{title}\" s$episode->{season}e$episode->{episode} of \"$episode->{grandparentTitle}\"\n";
	}
} else {
	print "  * No recent TV episodes\n";
}

rule();