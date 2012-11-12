#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Medac::API;

my $api = new Medac::API();

#print Dumper($api);

$api->dispatch();