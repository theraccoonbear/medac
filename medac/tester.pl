#!/usr/bin/perl
use lib 'Medac';

use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use POSIX;
use Config::Auto;

# custom
use Medac::File;
use Medac::Logging;

my $logger = new Medac::Logging();

print Dumper($logger);