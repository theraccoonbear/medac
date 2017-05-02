#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Data::Printer;
use Cwd 'abs_path';
use File::Basename;
use lib dirname(abs_path($0)) . '/../lib/';
use Medac::Downloader::WRS;

my $wrs = new Medac::Downloader::WRS();

my $episodes = $wrs->listEpisodesForSeason(2009, 2010);
#p($episodes);
die;
my $season_number = 30;
my $season_year = $season_number + 1980;
my $ep_num = 0;
foreach my $ep (@$episodes) {
	$ep_num++;
	print sprintf('The Woodwright\'s Shop - s%02de%02d - %s.mp4', $season_number, $ep_num, $episodes->{title}) . "\n"; 
}


#$wrs->grabEpisode(2365554475, '../media/The Woodwright\'s Shop - s35e08 - Bowl Carving with Peter Follansbee.mp4');
#$wrs->grabEpisode(2365554505, '../media/The Woodwright\'s Shop - s35e09 - Hollows and Rounds.mp4');
#$wrs->grabEpisode(2365554510, '../media/The Woodwright\'s Shop - s35e10 - Welsh Stick Chair I.mp4');
#$wrs->grabEpisode(2365554518, '../media/The Woodwright\'s Shop - s35e11 - Welsh Stick Chair II.mp4');
#$wrs->grabEpisode(2365554522, '../media/The Woodwright\'s Shop - s35e12 - Tool Smithing with Peter Ross.mp4');


#foreach my $ep (@$episodes) {
#	my $file = '../media/' . $ep->{title} . '.mp4';
#	if (-f $file) {
#		print STDERR "Already have $ep->{title}\n";
#	} else {
#		$wrs->grabEpisode($ep->{id}, $file);
#	}
#}