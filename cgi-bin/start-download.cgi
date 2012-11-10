#!/usr/bin/perl
use strict;
use warnings;
use API;

my $q = CGI->new();

sub pr {
	my $o = shift @_;
	
	print '<pre>';
	print Data::Dumper::Dumper($o);
	print '</pre>';
}

print "Content-Type: text/html\n\n";
print "<h1>HELLO, WORLD!</h1>";
pr($q);