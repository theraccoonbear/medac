package Medac::Config;

use Moose;

use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);
use File::Spec;




has 'settings' => (
  is => 'rw',
  isa => 'HashRef',
  default => sub {
		my $mod = __PACKAGE__ . '.pm';
		$mod =~ s/::/\//gi;
		
		my ($volume, $directory) = File::Spec->splitpath( $INC{$mod} );
		
		my @path_parts = split(/\//, $directory);
		pop @path_parts;
		$directory = join('/', @path_parts);
		
		my $config_file = File::Spec->catpath( $volume, $directory, 'config.json' );
		
		my $cfg_data = slurp($config_file);
		
		return decode_json($cfg_data);
	}
);

1