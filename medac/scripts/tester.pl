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
use Medac::Cache;
use Getopt::Long;
use Medac::Misc::Menu;
use Medac::Misc::Menu::Item;


my $womble = new Medac::Search::NZB::Womble(port => 80, protocol => 'http');
my $results = $womble->search('NOVA');
print Dumper($results);

my $menu = new Medac::Misc::Menu(title => "My Menu!");
print $menu->getMenu();