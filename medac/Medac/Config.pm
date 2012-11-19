package Medac::Config;

use Moose::Role;

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


has 'config' => (
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
		
		my $result = {};
			
		eval {
			$result = decode_json($cfg_data);
			1;
		};
		
		if ($@) {
			print "Content-Type: text/plain\n\n";
			my $err = $@;
			print encode_json({success => JSON::XS::false, payload => {error => $err}, message => "Error reading config.  Note: no single quotes allowed in JSON, use double quotes only."});
			exit;
		}
		
		return $result;
	}
);


sub drillex {
	my $self = shift @_;
	my $bits = shift @_;
	my $default = '____________MISSING';
	
	my $val = $self->drill($bits, $default);
	
	return $val ne $default;	
}

sub drill {
	my $self = shift @_;
	#my $obj = shift @_;
	my $bits = shift @_;
	my $default = shift @_ || undef;
	
	my $obj = $self->config;
	
	foreach my $bit (@{$bits}) {
		if (defined $obj->{$bit}) {
			$obj = $obj->{$bit};
		} else {
			$obj = $default;
			last;
		}
	}
	
	return $obj;
}

1
