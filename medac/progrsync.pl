#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Cache::FileCache;
use Number::Bytes::Human qw(format_bytes);
use Time::HiRes qw(gettimeofday usleep);
use DateTime::Format::Duration;

my $src_d = 0;
my $dest_d = 0;
my $delay = 3;
my $poll = 1;

GetOptions(
	's|src=s' => \$src_d,
	'd|dest=s' => \$dest_d,
	'delay|secondss=f' => \$delay,
	'poll!' => \$poll
);

# I need a 111 ms delay on my system.  autotune this at some point.
$delay = (($delay < .111 ? .112 : $delay) - 0.111) * 1000000;


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
	my $d = DateTime::Format::Duration->new(
		pattern => '%d:%H:%M:%S',
		normalize => 1
	);
	
	my $last_src;
	my $last_dest;
		
	
	while (1) {
		
		
	
		my $src = parse(`du -s -b $src_d 2>/dev/null`);
		my $dest = parse(`du -s -b $dest_d 2>/dev/null`);
		my $percent = sprintf('%.3f', ($dest->{bytes} / $src->{bytes}) * 100);
		
		$last_src = !$last_src ? $cache->get($src_d) : $last_src; 
		$last_dest = !$last_dest ? $cache->get($dest_d) : $last_dest;
		
		print "\n";
		print $human->format($dest->{bytes}) . ' of ' . $human->format($src->{bytes}) . " ($percent\%) - " . $human->format($src->{bytes} - $dest->{bytes}) . " remaining\n";
		if ($last_dest) {
			my $bytes_xfered = $dest->{bytes} - $last_dest->{bytes};
			my $timespan = ($dest->{ts} - $last_dest->{ts}) || 1;
			#my $time_diff = abs(($timespan * 1000000) - $delay);
			#print '' . ($timespan * 1000000) . ' <> ' . $delay . ' : ' . $time_diff;
			#if ($timespan * 1000000 > $delay) {
			#	print '-';
			#} elsif ($timespan * 1000000 < $delay) {
			#	print '+';
			#}
			#print "\n";
			
			my $bps = $bytes_xfered / $timespan;
			my $etr = ($src->{bytes} - $dest->{bytes}) / $bps;
			
			my $fmt_etr = $d->format_duration(
				DateTime::Duration->new(
					seconds => $etr
				)
			);
			
			print $human->format($bytes_xfered) . ' in ' . sprintf('%.2f', $timespan) . " seconds \@ " . $human->format($bps) . " / second\n";
			print "$fmt_etr remaining\n";
			
			
		}
		
		$last_src = $src;
		$last_dest = $dest;
		
		if (!$poll) {
			$cache->set($src_d, $src); 
			$cache->set($dest_d, $dest);
			exit(0);
		}
		usleep($delay);
	}
}