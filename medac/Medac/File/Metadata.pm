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
	
		
	my $details = `$self->ffmpeg -i '$file'`;
	chomp($details);
	if ($details =~ m/Duration: (?<duration>(?<hours>\d{2}):(?<minutes>\d{2}):(?<seconds>\d{2}).(?<ms>\d{2}))/gi) {
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