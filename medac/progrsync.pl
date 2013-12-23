#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Cache::FileCache;
use Number::Bytes::Human qw(format_bytes);
use Time::HiRes qw(gettimeofday usleep);

my $src_d = 0;
my $dest_d = 0;
my $delay = 3;
my $poll = 1;

GetOptions(
	's|src=s' => \$src_d,
	'd|dest=s' => \$dest_d,
	'delay|ms|milliseconds=i' => \$delay,
	'poll!' => \$poll
);

$delay *= 1000;

my $cache = Cache::FileCache->new();

sub parse {
	my $entry = shift @_;
	
	my $t = gettimeofday();
	my $ret_val = {
		bytes => 0,
		ts => $t
	};
	
	if ($entry =~ m/^(?<bytes>\d+)/) {
		$ret_val->{bytes} = $+{bytes};
	}
	
	return $ret_val;
}




if (-d $src_d && -d $dest_d) {
	my $human = Number::Bytes::Human->new(bs => 1000, si => 1);
	
	while (1) {
		my $last_src = $cache->get($src_d);
		my $last_dest = $cache->get($dest_d);
	
		my $src = parse(`du -s -b $src_d 2>/dev/null`);
		my $dest = parse(`du -s -b $dest_d 2>/dev/null`);
		my $percent = sprintf('%.3f', ($dest->{bytes} / $src->{bytes}) * 100);
		
		print "\n";
		print $human->format($dest->{bytes}) . ' of ' . $human->format($src->{bytes}) . " ($percent\%) - " . $human->format($src->{bytes} - $dest->{bytes}) . " remaining\n";
		if ($last_dest) {
			my $bytes_xfered = $dest->{bytes} - $last_dest->{bytes};
			my $timespan = $dest->{ts} - $last_dest->{ts};
			my $bps = $bytes_xfered / $timespan;
			print $human->format($bytes_xfered) . ' in ' . sprintf('%.2f', $timespan) . " seconds \@ " . $human->format($bps) . " / second\n";
		}
		
		
		$cache->set($src_d, $src);
		$cache->set($dest_d, $dest);
		usleep($delay);
	}
}