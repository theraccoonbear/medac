#!/usr/bin/perl
use lib 'Medac';
use JSON::XS;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Video::FrameGrab;
use POSIX;
use GD;
use Image::Resize;
use Digest::MD5 qw(md5 md5_hex);
use Text::Levenshtein qw(distance);
use Medac::Metadata::Source::IMDB;
use Slurp;

$| = 0;

my $config = decode_json(slurp('config.json')); #Config::Auto::parse('medac.yml', {format => 'yaml'});

my $tvr_cache;

my $md_imdb = new Medac::Metadata::Source::IMDB();

my $log_file = 'logs/' . time() . '.log';
my $no_log_file = 0;

sub logMsg {
	my $msg = shift @_ || '...';
	print "$msg\n";
	if (!$no_log_file) {
		open LFH, ">>$log_file" or $no_log_file = 1 ;
		if (!$no_log_file) {
			print LFH "$msg\n";
			close LFH;
		}
	}
}

sub bestMatch {
	my $orig = shift @_;
	my @vals = @{shift @_};
	my $best_dist = 100000;
	my $best_match = '';
	
	my $orig_clean = lc($orig);
	$orig_clean =~ s/[^A-Za-z0-9 ]+/ /gi;
	$orig_clean =~ s/\s{2,}/ /gi;
	
	#if ($orig ne $orig_clean) {
	#	logMsg "O: $orig, OC: $orig_clean";
	#}
	
	foreach my $v (@vals) {
		my $nv = lc($v);
		$nv =~ s/[^A-Za-z0-9 ]+/ /gi;
		$nv =~ s/\s{2,}/ /gi;
		
		#if ($v ne $nv) {
		#	logMsg "V: $v, NV: $nv";
		#}
		
		my $d = distance($orig_clean, $nv);
		
		#logMsg "$orig_clean : $nv : $d";
		
		if ($d == 0) {
			return $v;
		}
		
		if ($d < $best_dist) {
			$d = $best_dist;
			$best_match = $v;
		}
	}
	
	return $best_match;
}


sub showUsage {
	my $msg = shift @_;
	
	#logMsg "USAGE:";
	#logMsg "bfl.pl <json-output-path> <thumb-path>";
	
	if (defined $msg) {
		logMsg "  $msg";
	}
	
	logMsg "";
	exit 0;
}

my $video_dir = $config->{paths}->{video};
my $root_dir = $config->{paths}->{root};
my $thumb_width = $config->{thumbnails}->{width};
my $thumb_count = $config->{thumbnails}->{count};
my $chunks_per_file = int($config->{checksum}->{chunks_per_file});
my $entropy = int($config->{checksum}->{entropy});
my $rebuild_cfg = $config->{settings}->{rebuild_json_every};
my $do_rebuilds = 0;
my $last_rebuild;

my %unit_conversions = (
	'seconds' => 1, 'second' => 1, 'secs' => 1, 'sec' => 1, 's' => 1,
	'minutes' => 60, 'minute' => 60, 'mins' => 60, 'min' => 60, 'm' => 60,
	'hours' => 60 * 60, 'hour' => 60 * 60, 'hr' => 60 * 60, 'hrs' => 60 * 60, 'h' => 60 * 60,
	'days' => 60 * 60 * 24, 'day' => 60 * 60 * 24, 'd' => 60 * 60 * 24,
	'weeks' => 60 * 60 * 24 * 7, 'week' => 60 * 60 * 24 * 7, 'wks' => 60 * 60 * 24 * 7, 'wk' => 60 * 60 * 24 * 7, 'w' => 60 * 60 * 24 * 7,
);
my $unit_conversion_rgx = join('|', keys %unit_conversions);
my $rebuild_freq = 1000000;


if (defined $rebuild_cfg && $rebuild_cfg =~ m/(\d+)\s+($unit_conversion_rgx)/gi) {
	my $count = $1;
	my $units = lc($2);
	$do_rebuilds = 1;
	$rebuild_freq = $count * $unit_conversions{$units};
}



if ($root_dir !~ m/\/$/) {
	$root_dir .= '/';
}


my $json_output_to = $root_dir . $config->{paths}->{json};

if (-d $json_output_to) {
	if ($json_output_to !~ m/\/$/) {
		$json_output_to .= '/';
	}
	$json_output_to .= 'media.json';
}

if (-f $json_output_to) {
	unlink $json_output_to;
}

my $thumb_path = $root_dir . $config->{paths}->{thumbs};
if (! -d $thumb_path) {
	print "$thumb_path\n";
	showUsage("Thumb path is not a valid directory.");
}

if ($thumb_path !~ m/\/$/) {
	$thumb_path .= '/';
}


my @video_extensions = qw(avi mpg mpeg mp4 mov mkv);
my @audio_extensions = qw(mp3 ogg m4a m4p wav aac);

my $video_pattern = '\.(' . join('|', @video_extensions) . ')$';
my $audio_pattern = '\.(' . join('|', @audio_extensions) . ')$';
my $media_pattern = '\.(' . join('|', (@video_extensions, @audio_extensions)) . ')$';

my $media_root = {
 'TV' => {},
 'Movies' => {},
 'Music' => {},
 'Other' => {}
};

sub niceSize {
	# Will work up to considerable file sizes!
	
	my $fs = shift @_ || 0; #$_[0];	# First variable is the size in bytes
	my $dp = shift @_ || 0; #$_[1];	# Number of decimal places required
	
	my @units = ('bytes','kB','MB','GB','TB','PB','EB','ZB','YB');
	my $u = 0;
	$dp = ($dp > 0) ? 10**$dp : 1;
	while($fs > 1024){
		$fs /= 1024;
		$u++;
	}
	if($units[$u]){ return (int($fs*$dp)/$dp)." ".$units[$u]; } else{ return int($fs); }
}

sub convert_seconds_to_hhmmss {
  my $hourz=int($_[0]/3600);
  my $leftover=$_[0] % 3600;
  my $minz=int($leftover/60);
  my $secz=int($leftover % 60);
  return sprintf ("%02d:%02d:%02d", $hourz,$minz,$secz)
}

sub fileType {
	my $file = shift @_;
	
	if ($file =~ m/$video_pattern/i) {
		return 'video';
	} elsif ($file =~ m/$audio_pattern/i) {
		return 'audio';
	} else {
		return 'other';
	}
}

sub parsePath {
	my $path = shift @_ || '';
	
	$path =~ s/^\///gi;
	
	my $context = {
		'media_type' => 'unknown',
		'path' => $path
	};
	
	my @path_parts = split(/\//, $path);
	my $filename = $path_parts[-1];
	my $parent = $path_parts[-2];
	my $g_parent = $path_parts[-3];
	my $g_g_parent = $path_parts[-3];
	
	if ($path_parts[0] eq 'TV') {
		$context->{media_type} = 'TV';
		
		
		if ($parent =~ m/^(?<show_name>.+?)-(Season|Series)\s*(?<season_number>\d+)$/gi) {
			$context->{show_name} = $+{show_name};
			$context->{season_number} = $+{season_number} + 0;
		} elsif ($parent =~ m/(Season|Series)\s*(?<season_number>\d+)/gi) {
			$context->{show_name} = $g_parent;
			$context->{season_number} = $+{season_number} + 0;
		} else {
			$context->{show_name} = $parent;
		}
	
		if ($filename =~ m/^(?<season_number>\d{1,2}?)(?<episode_number>\d{2})[^\d]/gi) {
			$context->{season_number} = $+{season_number} + 0;
			$context->{episode_number} = $+{episode_number} + 0;
		} elsif ($filename =~ m/[sS]?(?<season_number>[12345][0-9]|0?[1-9])[xseE](?<episode_number>[0123]?[0-9])/gi) {
			$context->{season_number} = $+{season_number} + 0;
			$context->{episode_number} = $+{episode_number} + 0;
		} elsif ($filename =~ m/(Episode|Part)\s*(?<episode_number>\d+)/gi) {
			if (!defined $context->{season_number}) { $context->{season_number} = 1; }
			$context->{episode_number} = $+{episode_number} + 0;
		} elsif ($filename =~ m/(?<season_number>\d)(?<episode_number>\d{2})/gi) {
			if (!defined $context->{season_number}) { $context->{season_number} = $+{season_number}; }
			$context->{episode_number} = $+{episode_number};
		} elsif ($filename =~ m/^(?<episode_number>\d+)/gi) {
			$context->{episode_number} = $+{episode_number} + 0;
		} else {
			print "ERROR (Cannot Determine Season/Episode): $path\n";	
		}
		
		#print Dumper($context);
	} else {
		$context->{media_type} = 'Movie';
	}
	
	return $context;
} # parsePath()

sub outputJSON() {
	my $json_path = shift @_ || $json_output_to;
	my $base_obj;

	$base_obj->{media} = $media_root;
	$base_obj->{provider} = $config->{provider};
	
	logMsg('');
	logMsg('Encoding JSON...');
	my $json = encode_json($base_obj);
	logMsg('Writing to disk...');
	open MFH, ">$json_path" or die "Can't write JSON to $json_path: $!\n";
	print MFH $json;
	close MFH;
}

sub loadDir {
	my $dir = shift @_;
	my $pattern = shift @_ || '.+';
	my $md5 = Digest::MD5->new();
	
	if ($dir !~ /\/$/) {
		$dir .= '/';
	}
	
	opendir DFH, $dir or die "Can't read $dir: $!\n";
	my @FILES = readdir DFH;
	closedir DFH;
	
	my @ch_dirs;
	my @ch_files;
	
	foreach my $file (@FILES) {
		my $afp = $dir . $file;
		if ($file !~ m/^\.{1,2}$/) {
			if (-d $afp) {
				push @ch_dirs, loadDir($afp, $pattern);
			} else {
				if ($file =~ m/$pattern/i) {
					my $f_obj;
					
					
					
					$md5->reset();
				
					my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($afp);
					my $eff_entropy = $entropy < $size ? $entropy : $size;
					my $chunk_size = int($eff_entropy /  $chunks_per_file);
					my $step_size = int($size / $chunks_per_file);
					
					my $CSFH;
					open $CSFH, $afp || die "Can't read $afp: $!\n";
					binmode($CSFH);
					
					for (my $offset = 0; $offset < $chunks_per_file - 1 ; $offset += $step_size) {
						my $buf;
						my $rc = read($CSFH, $buf, $chunk_size, $offset);
						$md5->add($buf);
						
					}
					close $CSFH;
					
					my $file_md5 = $md5->hexdigest();
					
					if (fileType($file) eq 'video') {
						my $grabber = Video::FrameGrab->new(video => $afp);
						
						my $metadata = $grabber->meta_data();
						
						#$f_obj->{meta} = $metadata;
						
						$f_obj->{meta}->{length} = $metadata->{length};
						$f_obj->{meta}->{duration} = convert_seconds_to_hhmmss($metadata->{length});		
						$f_obj->{meta}->{video_width} = $metadata->{video_width};
						$f_obj->{meta}->{video_height} = $metadata->{video_height};
						$f_obj->{meta}->{video_fps} = $metadata->{video_fps};
						$f_obj->{meta}->{filename} = $file;
						$f_obj->{meta}->{filename} =~ s/^$video_dir//gi;
						$f_obj->{rel_path} = $afp;
						$f_obj->{rel_path} =~ s/^$video_dir//gi;
						
						logMsg $f_obj->{meta}->{filename};
						
						$f_obj->{md5} = $file_md5;
						
						my @thumb_ar = ();
						my $thumb_cnt = 0;
						for my $p ($grabber->equidistant_snap_times($thumb_count)) {
							$thumb_cnt++;
							my $thumb_file = $file_md5 . '-' . $p . '.jpg';
							my $img_fname = $thumb_path . $thumb_file;
							
							my $rel_img_fname = $img_fname;
							$rel_img_fname =~ s/^$root_dir//gi;
							
							if (-e $img_fname) {
								logMsg "    --> $rel_img_fname [exists]";
								push @thumb_ar, $rel_img_fname;
							} else {
								my $frame = $grabber->snap($p);
								my $image = GD::Image->new($frame);
								if (defined $image) {
									logMsg "    --> $rel_img_fname [created]";
									
									my ($width, $height) = $image->getBounds();
									my $new_width = $thumb_width;
									my $new_height = $height * ($new_width / $width);
									$image = Image::Resize->new($image);
									my $gd = $image->resize($new_width, $new_height);
									$image = $gd->jpeg();
									
									
									
									push @thumb_ar, $rel_img_fname;
									
									open IFN, ">$img_fname" or die "Can't write image $img_fname: $!";
									binmode IFN;
									print IFN $image;
									close IFN;
								} else {
									logMsg "    --> $rel_img_fname [failed]";
								} # image created?
							} # image exists?
						} # each frame grab
						$f_obj->{meta}->{thumbs} = \@thumb_ar;
						
						$f_obj->{size} = $size;
						$f_obj->{created} = $ctime;
						$f_obj->{modified} = $mtime;
						$f_obj->{name} = $file;
						$f_obj->{meta}->{niceSize} = niceSize($f_obj->{size}, 1);
					
						push @ch_files, $f_obj;
					
						my $ctxt = parsePath($f_obj->{rel_path});
						$f_obj->{ctxt} = $ctxt;
						
					
						if ($ctxt->{media_type} eq 'TV') {
							my $show_list = $md_imdb->searchSeries($ctxt->{show_name});
							my $show = $md_imdb->getShow($show_list->[0]);
							my $season = $md_imdb->getSeason($show, $ctxt->{season_number});
							my $episode = $season->[$ctxt->{episode_number}];
							
							if (ref $episode eq 'HASH') {
								$f_obj->{ctxt}->{episode_title} = $episode->{name};
								$f_obj->{imdb} = $episode;
								my $sub_ep_num = 0;
								my $sub_ep = '';
								
								while (defined $media_root->{TV}->{$ctxt->{show_name}}->{$ctxt->{season_number}}->{$ctxt->{episode_number} . $sub_ep}) {
									$sub_ep_num++;
									$sub_ep = '.' . $sub_ep_num;
								}
								
								$media_root->{TV}->{$ctxt->{show_name}}->{$ctxt->{season_number}}->{$ctxt->{episode_number} . $sub_ep} = $f_obj;
							
								logMsg('Program: ' . $f_obj->{ctxt}->{show_name} . 
												 ', Season: ' . $f_obj->{ctxt}->{season_number} .
												 ', Episode: ' . $f_obj->{ctxt}->{episode_number} . $sub_ep .
												 ', Title: ' . $f_obj->{ctxt}->{episode_title} . "\n");
							} else {
								logMsg("WARNING: Unknown episode.  Possible special or extra content?");
								#$md_imdb->dumpCache();
								#print Dumper($episode);
								#exit(0);
							}
						}
						
						if ($do_rebuilds) {
							my $elap = time() - $last_rebuild;
							
							if ($elap > $rebuild_freq) {
								logMsg('Periodic rebuild...');
								outputJSON();
								logMsg('Continuing processing...');
								$last_rebuild = time();
							} # time to rebuild?
						} # rebuilds?
						
					} # video?
				} # matches file pattern?
			} # dir or file?
		} # not . or ..
	} #each file
	
	@ch_dirs = sort(@ch_dirs);
	@ch_files = sort(@ch_files);
	
	my $dobj;
	$dobj->{name} = basename($dir);
	$dobj->{dirs} = \@ch_dirs;
	$dobj->{files} = \@ch_files;
	
	return $dobj;
}

$last_rebuild = time();
my $root = loadDir($video_dir, $media_pattern);

outputJSON();

logMsg;
logMsg "done.";