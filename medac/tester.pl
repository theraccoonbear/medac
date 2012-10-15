#!/usr/bin/perl
use lib 'Medac';

use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use POSIX;
use Config::Auto;
use Medac::Misc::TV::Series;

# custom
use Medac::File;
use Medac::Logging;

my $tv_search = new Medac::Misc::TV::Series();
my $srch_rslt;

#print "Searching for M*A*S*H*\n";
#$srch_rslt = $tv_search->search('M*A*S*H*');
#print Dumper($srch_rslt) . "\n";

my $show_name = 'Band of Brothers';

print "Searching for $show_name\n";
$srch_rslt = Medac::Misc::TV::Series->search($show_name);

#print scalar @{$srch_rslt->{results}
#print Dumper($srch_rslt) . "\n";

my $show = Medac::Misc::TV::Series->get($srch_rslt->[0]);

print Dumper($show);
#print $show->{synopsis};



#my $logger = new Medac::Logging();
#
#print Dumper($logger);