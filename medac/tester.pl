#!/usr/bin/perl
use FindBin;
use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use POSIX;
use Config::Auto;
use Medac::Metadata::Source::IMDB;

my $show_name = 'Firefly';
$show_name = 'Dexter';
$show_name = 'Band of Brothers';
$show_name = 'Eastbound and Down';

my $srch_rslt = Medac::Metadata::Source::IMDB->searchSeries($show_name);

print "Search for \"$show_name\" returned:\n";
print Dumper($srch_rslt);

my $show = Medac::Metadata::Source::IMDB->getShow($srch_rslt->[0]);

print "Show details:\n";
print Dumper($show);

my @seasons = keys %{$show->{seasons}};
my $s_max = $#seasons;
my $s_idx = floor(rand() * $s_max);
my $season_num = $seasons[$s_idx];

#print "::::: " . $s_idx . ' ::: ' . $season_num ; exit;
#$season_num = 3;

my $season = Medac::Metadata::Source::IMDB->getSeason($show, $season_num);

print "Season #$season_num:\n";
print Dumper($season);
