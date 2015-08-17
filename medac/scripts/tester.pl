#!/usr/bin/perl
use Cwd 'abs_path';

use FindBin;
use lib "$FindBin::Bin/..";

use FindBin;
use JSON::XS;
use strict;
use warnings;
use Data::Printer;
use File::Basename;
use File::Slurp;
use POSIX;
use Medac::Metadata::Source::IMDB;
use Medac::Metadata::Source::Plex;
use Medac::Metadata::Source::CouchPotato;
use Medac::Metadata::Source::SickBeard;
use Medac::Search::NZB::Womble;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Cache;
use Getopt::Long;
use Medac::Console::Menu;
use Medac::Console::Menu::Item;

my $config_file = dirname(abs_path($0)) . "/test-config.json";
my $file_data = read_file($config_file);
my $config = decode_json($file_data);



my $sb = new Medac::Metadata::Source::SickBeard($config->{sickbeard});
#p($sb->managedShows());
#p($sb->managedShows());

p($sb->search('Inside No. 9'));
#$sb->addShow(72965);
p($sb->getEpisodes(276840));