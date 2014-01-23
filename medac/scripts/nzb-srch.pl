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
#use POSIX;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Downloader::Sabnzbd;

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

# End Config

my $omg = new Medac::Search::NZB::OMGWTFNZBS($config->{'omgwtfnzbs.org'});
my $sab = new Medac::Downloader::Sabnzbd($config->{'sabnzbd'});

my $my_shows = $omg->searchTV({
	terms => 'NOVA',
	filter => sub {
		my $n = shift @_;
			$n->{season} >= 41 &&
			$n->{episode} == 12 &&
			$n->{video_quality} =~ m/(720p|HDTV)/ && 
			#$n->{group} eq 'alt.binaries.teevee'
		1;
	}
});

if (scalar @$my_shows < 1) {
	print "No matches";
} else {
	foreach my $show (sort {$a->{usenetage} <=> $b->{usenetage}} @$my_shows) {
		print Dumper($show);
		my $show_info = "NOVA s$show->{season}e$show->{episode}";
		#if ($sab->queueDownload($show->{getnzb}, $show->{release}, 'tv')) {
		#	print "$show_info queued in sabnzbd\n";
		#} else {
		#	print "$show_info couldn't be queued\n";
		#}
		#print $show->{release};
	}
}