package Medac::Downloader::WRS;
use Moose;
use Data::Printer;
use WWW::Mechanize;
use WWW::Mechanize::Cached;
use Web::Scraper;
use CHI;
use URI::Escape;
use Text::Unidecode;
use JSON::XS;
use POSIX;

has 'mech' => (
	is => 'rw',
	#isa => 'WWW::Mechanize::Cached',
	isa => 'WWW::Mechanize',
	default => sub {
		#my $m = new WWW::Mechanize::Cached(
		my $m = new WWW::Mechanize(
			agent => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36',
			autocheck => 1
		);
		$m->max_redirect(0);
		return $m;
	}
);

my $season_episode_scraper = scraper {
	process '[data-video-id]', 'ids[]' => '@data-video-id', 'titles[]' => sub { return $_->as_trimmed_text(); };
};

sub listEpisodesForSeason {
	my ($self, $start, $end) = @_;
	# http://www.pbs.org/woodwrightsshop/watch-on-line/watch-season-episodes/2015-2016-episodes/
	my $eps = [];
	my $url = 'http://www.pbs.org/woodwrightsshop/watch-on-line/watch-season-episodes/' . uri_escape($start) . '-' . uri_escape($end) . '-episodes/';
	$self->doGet($url);
	if ($self->mech->success) {
		my $cont = $self->mech->content;
		my $res = $season_episode_scraper->scrape($cont);
		
		my $idx = 0;
		foreach my $id (@{$res->{ids}}) {
			my $title = $res->{titles}->[$idx++];
			push @$eps, {title => $title, id => $id};
		}
	}
	return $eps;
}

sub doGet {
	my ($self, $url) = @_;
	$self->logMsg("FETCHING: $url\n");
	$self->mech->get($url);
	#$self->logMsg($self->mech->success ? "SUCCESS" : "FAIL";
	#$self->logMsg("\n";
}

sub logMsg {
	my ($msg) = @_;
	print STDERR $msg;
}

sub grabEpisode {
	my ($self, $episode_id, $output_file) = @_;
	my $chunks = $self->getEpisodeChunkList($episode_id);
	my $c_idx = 0;
	my $file_prefix = "../tmp/episode_" . $episode_id . "_chunk_";
	foreach my $c (@$chunks) {
		my $chunk_path = $file_prefix . sprintf('%04d', ++$c_idx) . ".ts";
		if (-f $chunk_path) {
			$self->logMsg('.');
		} else {
			$self->logMsg(" > Grabbing chunk $c_idx of " . scalar @$chunks . " to $chunk_path\n");
			$self->mech->get($c);
			$self->mech->save_content($chunk_path);
		}
	}
	$self->logMsg("All chunks downloaded.  Merging...\n");
	my $cmd = 'cat '. $file_prefix . '*.ts > "' . $output_file . '"';
	print "$cmd\n";
	system($cmd);
	$self->logMsg("done.\n");
	$cmd = 'rm ' . $file_prefix . '*.ts';
	print "$cmd\n";
	system($cmd);
	
}

sub getEpisodeChunkList {
	my ($self, $episode_id) = @_;
	my $chunks = [];
	my $url = 'http://www.pbs.org/woodwrightsshop/lunchbox_plugins/merlin_plugin/video_frame/' . uri_escape($episode_id) . '/';
	$self->doGet($url);
	if ($self->mech->success) {
		my $cont = $self->mech->content;
		my $data = decode_json($cont);
		if ($data->{player_code} && $data->{player_code}->{template}) {
			if ($data->{player_code}->{template} =~ m/src=['"](?<url>[^"']+)["']/i) {
				$self->doGet($+{url});
				if ($self->mech->success) {
					if ($self->mech->content =~ m/['"]recommended_encoding['"]\s*:\s*(?<json>\{.+?\})/gism) {
						my $json = $+{json};
						$json =~ s/'/"/g;
						my $enc = decode_json($json);
						if ($enc->{url}) {
							# http://urs.pbs.org/redirect/17724af1ba45488d9abec7937539ea28/?format=jsonp&callback=jQuery18308222382439998503_1457911578478&_=1457911578640
							$enc->{url} .= '?format=jsonp&callback=jQuery123456789_987654321&_=987654321';
							
							$self->doGet($enc->{url});
							
							if ($self->mech->success) {
								$cont = $self->mech->content;
								$cont =~ s/^jQuery\d+_\d+\(//gi;
								$cont =~ s/\)$//g;
								$data = decode_json($cont);
								if ($data->{url}) {
									my $uri = $data->{url};
									$self->doGet($uri);
									if ($self->mech->success) {
										if ($self->mech->content =~ m/URI="(?<uri>[^"]+?2500k[^"]+)"/gism) {
											$url = $+{uri};
											$uri =~ s/\/[^\/]+$/\//;
											my $base_uri = $uri;
											$uri = $base_uri . $url;
											$self->doGet($uri);
											if ($self->mech->success) {
												my $lines = [split(/\n/, $self->mech->content)];
												my $used = {};
												foreach my $l (@$lines) {
													my $chunk_uri = $base_uri . $l;
													if ($l =~ m/\.ts$/ && $l !~ m/^#/ && !$used->{$chunk_uri}) {
														$used->{$chunk_uri} = 1;
														push @$chunks, $chunk_uri;
													}
												}
												$self->logMsg("Successfully found " . scalar @$chunks . " chunks\n");
											} else {
												die "Couldn't fetch IFRAME index file";
											}
										} else {
											die "Can't find IFRAME index URI";
										}
									} else {
										die "Unable to fetch chunk index file";
									}
								} else {
									die "Couldn't find the chunk index URI in m3u8";
								}
							} else {
								die "Couldn't fetch recommended encoding URL";
							}
						} else {
							die "No recommended encoding URL in JSON";
						}
					} else {
						die "Unable to parse out recommended encoding";
					}
				} else {
					die "Unable to fetch video data";
				}
			} else {
				die "No SRC attribute for IFRAME";
			}
		} else {
			die "Unfamiliar JSON structure";
		}
	} else {
		die "Unable to fetch Merlin JSON";
	}
	return $chunks;
}

1;