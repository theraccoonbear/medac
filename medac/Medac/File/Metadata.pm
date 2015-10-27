package Medac::File::Metadata;

use Moose;
use Data::Printer;

has 'ffmpeg' => (
	is => 'rw',
	isa => 'Maybe[Str]',
	default => sub {
		my $ffmpeg = `which ffmpeg`;
		chomp($ffmpeg);
		if (! -f $ffmpeg || ! -e $ffmpeg) {
			return undef;
		} else {
			return $ffmpeg;
		}
	}
);

has 'avconv' => (
	is => 'rw',
	isa => 'Maybe[Str]',
	default => sub {
		my $avconv = `which avconv`;
		chomp($avconv );
		if (! -f $avconv || ! -e $avconv ) {
			return undef;
		} else {
			return $avconv ;
		}
	}
);

sub videoDetails {
	my $self = shift @_;
	my $file = shift @_;
	
	my $resp = {};
	
	if (! $self->ffmpeg && ! $self->avconv) {
		print STDERR "Neither ffmpeg or avconv is installed!\n";
		return $resp;
	}
	
	if (! -f $file) {
		print STDERR "Cannot find: $file\n";
		return $resp;
	}
	
	$resp->{size} = (stat($file))[7];
	
	
	my $video_tool = $self->avconv || $self->ffmpeg;
	my $cmd = "$video_tool -i '$file' 2>&1";
	my $details = `$cmd`;
	chomp($details);
	if ($details =~ m/Duration: (?<duration>(?<hours>\d{2}):(?<minutes>\d{2}):(?<seconds>\d{2}\.\d+))/gism) {
		$resp->{duration} = {
			raw => $+{duration},
			hours => 1 * $+{hours},
			minutes => 1 * $+{minutes},
			seconds => 1 * $+{seconds}
		};
		
		$resp->{duration}->{in_seconds} = ($resp->{duration}->{hours} * 60 * 60) + ($resp->{duration}->{minutes} * 60) + $resp->{duration}->{seconds};
		$resp->{duration}->{in_minutes} = ($resp->{duration}->{hours} * 60) + $resp->{duration}->{minutes} + ($resp->{duration}->{seconds} / 60);
		$resp->{duration}->{in_hours} = $resp->{duration}->{hours} + ($resp->{duration}->{minutes} / 60) + ($resp->{duration}->{seconds} / 60 / 60);
	}
	
	if ($details =~ m/,\s+(?<width>\d+)x(?<height>\d+)/gism) {
		$resp->{dimensions} = {
			width => 1 * $+{width},
			height => 1 * $+{height}
		};
	}
	
	
	return $resp;
}

1;