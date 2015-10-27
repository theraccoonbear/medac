package Medac::File::Metadata;

use Moose;
use Data::Printer;

has 'ffmpeg' => (
	is => 'rw',
	isa => 'Maybe[Str]',
	default => sub {
		my $ffmpeg = `which ffmpeg`;
		chomp($ffmpeg);
		p($ffmpeg);
		if (! -f $ffmpeg || ! -e $ffmpeg) {
			return undef;
		} else {
			return $ffmpeg;
		}
	}
);

sub videoDetails {
	my $self = shift @_;
	my $file = shift @_;
	
	if (! $self->ffmpeg ) {
		print STDERR "FFMPEG IS NOT INSTALLED!\n";
		return;
	}
	
	if (! -f $file) {
		print STDERR "CANNOT READ: $file\n";
		return;
	}
	
	my $ffmpeg = $self->ffmpeg;
	my $cmd = "$ffmpeg -i '$file' 2>&1";
	print "Running: $cmd\n";
	my $details = `$cmd`;
	chomp($details);
	if ($details =~ m/Duration: (?<duration>(?<hours>\d{2}):(?<minutes>\d{2}):(?<seconds>\d{2}).(?<ms>\d+))/gism) {
		return {
			duration => {
				raw => $+{duration},
				hours => $+{hours},
				minutes => $+{minutes},
				seconds => $+{seconds},
				ms => $+{ms}
			}
		};
	} else {
		return;
	}
	
}

1;