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
use Medac::Search::NZB::Womble;
use Medac::Search::NZB::OMGWTFNZBS;
use Medac::Cache;
use Getopt::Long;
use Medac::Console::Menu;
use Medac::Console::Menu::Item;

my $config_file = dirname(abs_path($0)) . "/test-config.json";
my $file_data = read_file($config_file);
my $config = decode_json($file_data);


my $womble = new Medac::Search::NZB::Womble();
my $omg = new Medac::Search::NZB::OMGWTFNZBS($config->{'omgwtfnzbs.org'});

my $term = 'cross country';

print ">>>> Womble <<<<\n";

my $results = $womble->search($term);
print Dumper($results);

print ">>>> OMG <<<<\n";

$results = $omg->searchTV({terms => $term});
print Dumper($results);

#my $menu = new Medac::Console::Menu(title => "My Menu!");
#print $menu->getMenu();