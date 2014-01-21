#!/usr/bin/perl
use Cwd 'abs_path';

use FindBin;
use lib "$FindBin::Bin/..";

use FindBin;
use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use File::Slurp;
use POSIX;
use Config::Auto;
use Medac::Metadata::Source::IMDB;
use Medac::Metadata::Source::Plex;
use Medac::Metadata::Source::CouchPotato;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Cache;
use Getopt::Long;


# Config

my $config_file = 'test-config.json';

my $config = {};
my $host_name = 0;
my $port = 32400;
my $username = 0;
my $password = 0;

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
	
	$host_name = $config->{hostname} || $host_name;
	$port =  $config->{port} || $port;
	$username = $config->{username} || $username;
	$password = $config->{password} || $password;
} else {
	GetOptions(
		'h|host|hostname=s' => \$host_name,
		'p|port' => \$port,
		'u|user|username=s' => \$username,
		'pass|password=s' => \$password,
	);
}

# End Config


#my $omg_cfg = $config->{'omgwtfnzbs.org'};
#
#my $omg = new Medac::Search::NZB::OMGWTFNZBS(
#	username => $omg_cfg->{username},
#	password => $omg_cfg->{password},
#	apiKey => $omg_cfg->{apiKey},
#);
#
#my $nova_shows = $omg->search('grace');
#foreach my $show (reverse @$nova_shows) {
#	print Dumper($show);
#}

#my $imdb = new Medac::Metadata::Source::IMDB();


my $plex = new Medac::Metadata::Source::Plex(
	hostname => $host_name,
	port => $port,
	username => $username,
	password => $password,
	maxage => 10 * 60 * 60 * 24
);

print $plex->nowPlaying();

#my $couchPotato = new Medac::Metadata::Source::CouchPotato(
#	hostname => $config->{couchPotato}->{hostname},
#	port => $config->{couchPotato}->{port},
#	apiKey => $config->{couchPotato}->{apiKey},
#	protocol => $config->{couchPotato}->{protocol},
#	username => $config->{couchPotato}->{username},
#	password => $config->{couchPotato}->{password}
#);
#
#my $movies = $couchPotato->managedMovies();
#
##print Dumper($movies);
#
#foreach my $movie (@$movies) {
#	$movie = $movie->{library};
#	print "$movie->{info}->{titles}->[0] ($movie->{info}->{year}) [$movie->{info}->{imdb}]\n";
#}
#
