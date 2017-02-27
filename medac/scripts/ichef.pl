#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use Cwd 'abs_path';
use File::Basename;
use lib dirname(abs_path($0)) . '/../lib';
use Getopt::Long;
use Data::Printer;
use Medac::Search::TV::TheTVDB;
use Medac::Search::TV::IronChefFans;
use Medac::File::Metadata;
use Text::Levenshtein qw(distance);
use JSON::XS;


my $meta = new Medac::File::Metadata();
my $tvdb = new Medac::Search::TV::TheTVDB();
my $ichef = new Medac::Search::TV::IronChefFans();

my $save_root = `echo ~/Desktop/sandbox/Iron Chef/`;
chomp($save_root);

GetOptions ("path=s" => \$save_root);

my $listing = $ichef->getCategoryListing(1);

foreach my $e (sort { $a->{season} <=> $b->{season} or $a->{episode} <=> $b->{episode} } @$listing) {
	if ($e->{season} =~ m/^\d+$/ && $e->{episode} =~ m/^\d+$/) {
		
		my $dir = $save_root . 'Season ' . $e->{season} . '/';
		
		my $file = $dir . 'Iron Chef - s' . $e->{season} . 'e' . sprintf('%02d', $e->{episode})  . ' - ' . $e->{ingredient} . ($e->{overtime} ? ' [' . $e->{overtime} . ']' : '') . ' (' . $e->{iron_chef} . ' vs. ' . $e->{challenger} . ').avi';
		
		print "$file\n";
		
		if (! -d $dir ) {
			mkdir $dir;
		}
		
		if (! -f $file) {
			$ichef->downloadFile($e->{id}, $file);
		} else {
			print STDERR "Skipping $file\n";
			my $details = $meta->videoDetails($file);
			p($details);
			if (! $details->{duration} || $details->{duration}->{minutes} < 38) {
				print "Uh Oh! Press any key when ready to continue...";
				my $wait = <STDIN>;
			}
			
		}
		
		
	} else {
		print STDERR "Skipping...";
		p($e);
	}
}


exit(0);




my $path = `echo ~/Desktop/medac/Video/TV/Iron Chef/Season 1`;
chomp($path);

GetOptions ("path=s" => \$path);

if (! defined $path || ! -d $path) {
	print STDERR <<__USAGE;
Usage:
  ichef.pl --path <path-to-scan>
__USAGE

	exit(1);
}

if ($path !~ m/\/$/) {
	$path .= '/';
}


opendir DFH, $path;
my $files = [ grep { /\.avi$/ } grep { $_ !~ m/^\.{1,2}$/ && ! -d $path . $_ } readdir DFH ];
closedir DFH;

my $episodes = $tvdb->getEpisodes(71991);

sub norm {
	my $val = shift @_;
	$val = lc($val);
	$val =~ s/[^A-Za-z\s]/ /gi;
	$val =~ s/s$//gi;
	$val =~ s/\s+/ /gi;
	return $val;
}

sub bestMatch {
	my $file = shift @_;
	
	my $best_ep;
	my $best_ep_dist = 100000;
	
	foreach my $ep (@$episodes) {
		my $dist = distance(norm($ep->{ingredient}), norm($file->{ingredient}));
		if ($dist == $best_ep_dist) {
			if ($ep->{ingredient_count} eq $file->{count}) {
				$best_ep = $ep;
			}
		} elsif ($dist < $best_ep_dist) {
			$best_ep_dist = $dist;
			$best_ep = $ep;
		}
	}
	return $best_ep;
}



foreach my $f (@$files) {
	my $fpath = $path . $f;
	if ($f =~ m/^Iron Chef\s*-\s*(?<ep>[^\[]+?)\s\[/i) {
		my $ep = $+{ep};
		$ep =~ s/\s*battle\s*/ /gi;
		
		my $count = 1;
		if ($ep =~ m/^(?<ep>.+?)\s(?<count>\d+)$/) {
			$ep = $+{ep};
			$count = $+{count};
		}
		
		my $battle = {
			file => $f,
			path => $fpath,
			ingredient => $ep,
			overtime => 1==0,
			count => $count
		};
		if ($ep =~ m/^(?<orig>.+?)\sovertime[^-]+-\s*(?<true>.+)$/i) {
			#print "$f ==> $+{true} ($+{orig})\n";
			$battle->{ingredient} = $+{true};
			$battle->{overtime} = $+{orig};
			
		}
		$battle->{ingredient} =~ s/^\s+//;
		$battle->{ingredient} =~ s/\s+$//;
		
		my $match = bestMatch($battle);
		p($battle);
		p($match);
		my $new_name = 'Iron Chef - s' . $match->{season} . 'e' . $match->{episode} . ' - ' . $match->{iron_chef} . ' vs. ' . $match->{challenger} . ' (' . $match->{ingredient} . ').avi';
		print "mv '$battle->{file}' '$new_name'\n";
		print "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
	}
	
	
}