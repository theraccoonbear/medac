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
use Medac::Misc::Menu;
use Medac::Misc::Menu::Item;

my $menu = new Medac::Misc::Menu(title => "My Menu!");


$menu->addItem(new Medac::Misc::Menu::Item(key => 1, label => "My item"));
$menu->addItem(new Medac::Misc::Menu::Item(key => 2, label => "My other item"));

print $menu->getMenu();