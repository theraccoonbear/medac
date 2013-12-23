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
use Medac::Cache;
use Getopt::Long;

my $imdb = new Medac::Metadata::Source::IMDB();

my $scan_dir = '.';

GetOptions(
	'd|dir=s' => \$scan_dir
);

if (! -d $scan_dir) {
	print "Bad Dir: $scan_dir\n";
	exit(0);
} else {
	print "OK: $scan_dir\n";
}

opendir DFH, $scan_dir;
my @files = readdir DFH;
@files = map { m/^[^\.].+\.(?:avi|mp4|mkv|mpg)$/i ? $_ : (); } @files;
#print Dumper(@files); 
closedir DFH;


foreach my $f (@files) {
	my $s = $f;
	$s =~ s/Iron Chef\s*-\s*//gis;
	$s =~ s/\s\[.+$//gis;
	$s =~ s/Battle//gis;
	$s =~ s/\s+/ /gis;
	$s =~ s/^\s+//gis;
	$s =~ s/\s+$//gis;
	
	my $search = "\"Iron Chef\" $s";
	
	print "SEARCHING: $s\n";
	my $results = $imdb->find($search, 'TV Episode');
	#print Dumper($results);
	foreach my $sections (@{$results->{sections}}) {
		#print Dumper($sections) . "\n";
		if ($sections->{name} eq 'Titles') {
			my $cnt = 0;
			foreach my $entry (sort {$imdb->dist($a->{title}, $s) <=> $imdb->dist($b->{title}, $s) } @{$sections->{entries}}) {
				if ($entry->{show_title} eq 'Iron Chef') {
					$cnt++;
					my $dist = $imdb->dist($entry->{title}, $s);
					print Dumper($entry);
					print "\"$s\" \"$entry->{title}\" ($dist)\n";
					exit if $cnt == 10;
				}
				
			}
		}
		
	}
	#print "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
}


#my $cache = new Medac::Cache('context'=>'TESTER');
#my $imdb = new Medac::Metadata::Source::IMDB();
#
##$cache->store('x', {'thing'=>'y'});
##$cache->dump();
##exit;
#
#my $show_name = 'Firefly';
#$show_name = 'Dexter';
#$show_name = 'Band of Brothers';
#$show_name = 'Eastbound and Down';
#
#my $srch_rslt = $imdb->searchSeries($show_name);
#
#print "Search for \"$show_name\" returned:\n";
##print Dumper($srch_rslt);
#
#my $show = $imdb->getShow($srch_rslt->[0]);
#
#print "Show details:\n";
##print Dumper($show);
#
#my @seasons = keys %{$show->{seasons}};
#my $s_max = $#seasons;
#my $s_idx = floor(rand() * $s_max);
#my $season_num = $seasons[$s_idx];
#
##print "::::: " . $s_idx . ' ::: ' . $season_num ; exit;
##$season_num = 3;
#
#my $season = $imdb->getSeason($show, $season_num);
#
#print "Season #$season_num:\n";
##print Dumper($season);
#
#print $imdb->dumpCache();
