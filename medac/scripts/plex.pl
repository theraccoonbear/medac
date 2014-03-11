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
use File::Slurp;
use Mojo::DOM;
use JSON::XS;
use Time::HiRes qw(usleep);
use URI::Escape;
use Getopt::Long;
use DateTime;
use Medac::Metadata::Source::Plex;
use Medac::Metadata::Source::IMDB;
use Email::Send;
use Email::Send::Gmail;
use Email::Simple::Markdown;
use POSIX;
use Encode;
use IO::Handle;

STDERR->autoflush(1);
STDOUT->autoflush(1);

my $now = time();

# Disable output buffering
#select((select(STDOUT), $|=1)[0]);

my $ua_string = "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.A.B.C Safari/525.13";

my $config = {};

my $max_days = 7;
my $host_name = 0;
my $port = 32400;
my $username = 0;
my $password = 0;
my $config_file = 'test-config.json';

#my $image_base = 0;
#my $from_email = 0;
#my $to_email = 0;
#my $subject = 0;
#my $email_pass;

my $script_started = time();
my $action_started;

GetOptions(
	'config=s' => \$config_file
);

if ($config_file && -f $config_file) {
	my $file_data = read_file($config_file);
	$config = decode_json($file_data);
	
	$max_days = $config->{max_days} || $max_days;
	$host_name = $config->{hostname} || $host_name;
	$port =  $config->{port} || $port;
	$username = $config->{username} || $username;
	$password = $config->{password} || $password;
} else {
	GetOptions(
		'm|max|maxdays=i' => \$max_days,
		'h|host|hostname=s' => \$host_name,
		'p|port' => \$port,
		'u|user|username=s' => \$username,
		'pass|password=s' => \$password,
	);
}



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

my $message = [];

my $imdb = new Medac::Metadata::Source::IMDB();

my $plex = new Medac::Metadata::Source::Plex(
	hostname => $host_name,
	port => $port,
	username => $username,
	password => $password,
	maxage => $max_days * 60 * 60 * 24
);



sub dbg {
	my $dbg = shift @_ || ' ';
	my $timing = shift @_ ? 1 : 0;
	print STDERR "DEBUG: " . ($dbg);
	my $now = time();
	if ($timing && defined $action_started) {
		my $elap = $now - $action_started;
		print STDERR " ($elap seconds)";
	}
	$action_started = $now;
	
	print STDERR "\n";
}

sub msg {
	my $m = shift @_ || ' ';
	
	my @lines = split(/\n/, $m);
	foreach my $l (@lines) {
		push @$message, $l;
		print "$l\n";
	}
}

sub getMessage {
	return join("\n", @$message);
}

sub rule {
	msg;
	msg '----';
	msg;
}

sub trim {
	my $s = shift @_;
	$s =~ s/^[^A-Za-z]+//gi;
	$s =~ s/[^A-Za-z]+$//gi;
	return $s;
}

dbg "Getting recent plex movies...";
my $recent_movies = $plex->recentMovies();
dbg "Done.", 1;
dbg "Getting recent plex TV...";
my $recent_episodes = $plex->recentEpisodes();
dbg "Done.", 1;

my $new_count = 0;
my $max_posters = 5;
my $movie_poster_count = 0;
my $used = {};
my $movie_posters = [];

my $tv_poster_count = 0;
my $tv_posters = [];

my $imdb_shows_loaded = {};

foreach my $show (sort { $a->{age} <=> $b->{age} } @$recent_episodes) {
	my $show_title = $show->{grandparentTitle};
	my $is_new = $show->{age} <= 60 * 60 * 24;
	if ($is_new && !$imdb_shows_loaded->{$show_title}) {
		
		dbg "Loading IMDB metadata for TV \"$show_title\"...";
		my $results = $imdb->find($show_title, 'TV');
		dbg "Done.", 1;
		$results = $results->{sections};
		$results =  $results->[0];
		$results =  $results->{entries};
		
		
		#print Dumper(scalar @$results); exit(0);
		my $count = scalar @$results;
		if (scalar $count > 0) {
			my $imdb_tv = $results->[0];
			my $poster_url = $imdb_tv->{poster};
			$poster_url =~ s/S[XY]\d+_CR.+_\.jpg/SX100_CR0,0,100,150_.jpg/gi;
			if (!$used->{$poster_url}) {
				push @$tv_posters, "![$show->{grandparentTitle}]($poster_url \"$show->{grandparentTitle}\")";
				$used->{$poster_url} = 1;
				$tv_poster_count++;
			}
		}
		
		#if ($tv_poster_count >= $max_posters) {
		#	my $more = (scalar @$recent_episodes) - $max_posters;
		#	if ($more != 0) {
		#		push @$tv_posters, " plus $more more";
		#	}
		#	last;
		#}
		
		$imdb_shows_loaded->{$show_title} = 1;
	}
}

$used = {};

foreach my $movie (sort { $a->{age} <=> $b->{age} } @$recent_movies) {
	my $movie_title = $movie->{title};
	my $is_new = $movie->{age} <= 60 * 60 * 24;
	if ($is_new) {
		dbg "Loading IMDB metadata for movie \"$movie_title\"...";
		my $results = $imdb->find($movie_title, 'Movie');
		dbg "Done.", 1;
		$results = $results->{sections};
		$results =  $results->[0];
		$results =  $results->{entries};
	
		if (scalar @$results > 0) {
			my $imdb_movie = $results->[0];
			
			my $poster_url = $imdb_movie->{poster};
			$movie->{imdb_url} = 'http://www.imdb.com' . $imdb_movie->{url};
			$poster_url =~ s/S[XY]\d+_CR.+_\.jpg/SX100_CR0,0,100,150_.jpg/gi;
			#http://ia.media-imdb.com/images/M/MV5BMTQzMzMwNDExMV5BMl5BanBnXkFtZTcwMzE5MjU3OQ@@._V1_SX100_CR0,0,100,150_.jpg
			if (!$used->{$poster_url}) {
				push @$movie_posters, "![$movie->{title}]($poster_url \"$movie->{title}\")";
				$used->{$poster_url} = 1;
				$movie_poster_count++;
			}
		}
	}
	#if ($movie_poster_count >= $max_posters) {
	#	my $more = (scalar @$recent_movies) - $max_posters;
	#	if ($more > 0) {
	#		push @$movie_posters, " plus $more more";
	#	}
	#	last;
	#}
}

my $m_posters = join(' ' , @$movie_posters);
my $t_posters = join(' ' , @$tv_posters);


my $header = <<__MSG;
# Hot Damn!
 
Looks like we've got some new stuff for you!
 
$m_posters

$t_posters
 
__MSG

msg $header;
msg "## Recent Movies";
msg;

if (scalar @$recent_movies > 0) {
	foreach my $movie (sort { $a->{age} <=> $b->{age} } @$recent_movies) {
		$movie->{summary} = trim($movie->{summary});
		$movie->{shortSummary} = trim(length $movie->{summary} > 100 ? substr($movie->{summary}, 0, 100) : $movie->{summary});
		my $disp_dur = 'unknown duration';
		if ($movie->{duration}) {
			my $dur_minutes = ceil($movie->{duration} / 1000 / 60);
			$disp_dur = "$dur_minutes minutes"
		}
		my $is_new = $movie->{age} <= 60 * 60 * 24;
		$new_count += $is_new ? 1 : 0;
		my $notice = $is_new ? "![Downloaded in the last 24 hours]($config->{image_base}/images/new-email.gif \"Downloaded in the last 24 hours\") " : '';
		
		
		my $trailer_search = 'https://www.youtube.com/results?search_query=' . uri_escape_utf8('"' . $movie->{title} . '" ' . $movie->{year} . ' HD trailer');
		
		if ($is_new) {
			msg "  * $notice**$movie->{title}** ($movie->{year}) / $disp_dur / [YouTube Trailer]($trailer_search) / [IMDB]($movie->{imdb_url})";
			$movie->{summary} =~ s/\n/ /gi;
			$movie->{summary} =~ s/^[\s\n\r\l]+//gi;
			$movie->{summary} =~ s/[\s\n\r\l]+$//gi;
			msg "    : *$movie->{summary}*";
		}
		#print Dumper($movie);
	}
} else {
	msg "  * No recent movies";
}

msg;

msg "## Recent TV";
msg;


if (scalar @$recent_episodes > 0) {
	foreach my $episode (sort { $a->{age} <=> $b->{age} } @{$recent_episodes}) {
		$episode->{season} = sprintf('%02d', $episode->{parentIndex});
		$episode->{episode} = sprintf('%02d', $episode->{index});
		
		my $is_new = $episode->{age} <= 60 * 60 * 24;
		$new_count += $is_new ? 1 : 0;
		my $notice = $is_new ? "![Downloaded in the last 24 hours]($config->{image_base}/images/new-email.gif \"Downloaded in the last 24 hours\") " : '';
		
		if ($is_new) {
			msg "  * $notice**$episode->{title}** s$episode->{season}e$episode->{episode} of *$episode->{grandparentTitle}*";
			if (length($episode->{summary}) > 0) {
				$episode->{summary} =~ s/\n/ /gi;
				$episode->{summary} =~ s/^[\s\n\r\l]+//gi;
				$episode->{summary} =~ s/[\s\n\r\l]+$//gi;
				msg "    : *$episode->{summary}*";
			}
		} # is new?
	}
} else {
	msg "  * No recent episodes";
}


my $footer = <<__FOOTER;

Stay tuned, there'll be more to come!

__FOOTER

msg $footer;




if (scalar @$recent_episodes > 0 || scalar @$recent_movies > 0) {
	dbg "Sending email  to $config->{to_email}...";
	
	my $email_msg = getMessage();
	my $email_bytes = encode('utf8', $email_msg);
  
	
	my $email = Email::Simple::Markdown->create(
		header => [
			From    => $config->{from_email},
			To      => $config->{to_email},
			Subject => $config->{subject},
		],
		attributes => {
			charset  => 'utf8',
		},
		#body => $email_msg,
		charset => 'utf8',
    body => $email_bytes,
	);
	
	my $sender = Email::Send->new(
		{
			mailer      => 'Gmail',
			mailer_args => [
				username => $config->{from_email},
				password => $config->{mail_pass},
			]
		}
	);
		
	eval { $sender->send($email) };
	die "Error sending email: $@" if $@;
	dbg "Done.", 1;
}

dbg "" . (time() - $script_started) . " second(s) elapsed in total.";