package Medac::API;
#use lib '../../../medac/Medac';

use Moose;

use lib '..';
#use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use Medac::API::Default;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);




has 'config' => (
  is => 'rw',
  isa => 'HashRef',
  default => sub { return decode_json(slurp('../medac/config.json')); }
);

has 'q' => (
  is => 'rw',
  isa => 'CGI',
  default => sub { return CGI->new; }
);

has 'root_path' => (
	is => 'ro',
	isa => 'Str',
	default => sub {
		my $path = abs_path(__FILE__);
		$path =~ s/\/[^\/]+$/\//gi;
		return $path;
	}
);


#my $q = CGI->new;


sub pr {
	my $self = shift @_;
	my $o = shift @_;
	
	print "Content-Type: text/html\n\n";
	print '<pre>';
	print Data::Dumper::Dumper($o);
	print '</pre>';
	exit;
}

sub json_pr {
	my $self = shift @_;
	my $o = shift @_;
	my $message = shift @_ || 'Call successful';
	my $success = shift @_;
	
	$success = $success ? JSON::XS::true : JSON::XS::false;
	
	my $json = encode_json({
		'success' => $success,
		'payload' => $o,
		'message' => $message
		});
	
	# print "Content-Type: application/x-json\n\n";
	print "Content-Type: text/plain\n\n";
	print $json;
	exit;
}

sub error {
	my $self = shift @_;
	my $msg = shift @_ || "Unknown error";
	
	$self->json_pr({}, $msg, 0);
}

sub underscoreToCamelCase {
	my $self = shift @_;
	my $name = shift @_;
	
	$name =~ s/_([a-z])/\U$1/gi;
	
	return ucfirst($name);
}

sub utoc {
	my $self = shift @_;
	my $name = shift @_;
	return $self->underscoreToCamelCase($name);
}

sub getModel {
	my $self = shift @_;
	#my $pl = shift @_;
	my $model = shift @_; #$pl->{model};
	
	
	my $fq_class_name = "Medac::API::$model";
	my $model_path = "Medac/API/$model.pm";
	
	my $ci = {};
	
	if (-f $model_path) {
		require $model_path;
		$ci = new $fq_class_name();
	}
	
	return $ci;
}

sub dispatch {
  my $self = shift @_;
  
  my $debug = ();
  
  my $model = 'Default';
  my $action = 'Index';
  my $params = {
	'named' => {},
	'numerical' => []
	};

  
  
  
  my @path_parts = split(/\//, $self->q->param('path'));
  
  my $p_cnt = scalar @path_parts;
  
  if ($p_cnt == 0) {
	$self->json_pr({}, "You're giving me nothin' here.", 0);
  } elsif ($p_cnt >= 1) {
	$model = $self->utoc($path_parts[0]);
  }
  
  if ($p_cnt >= 2) {

	$action = lc($path_parts[1]); #$self->utoc($path_parts[1]);
	my @prms = @path_parts[2 .. scalar @path_parts - 1];
	
	
	foreach my $p (@prms) {
		my $pn = '';
		my $pv = $p;
		if ($p =~ m/^([a-zA-Z_-]+):(.+?)$/) {
			$pn = $1;
			$pv = $2;
			$params->{named}->{$pn} = $pv;
		}
		
		push @{$params->{numerical}}, $pv;
	}
  }
  
  
  
  push @INC, $self->root_path;
  
  my $pl = {
	'model' => $model,
	'action' => $action,
	'params' => $params
	};
  
  $model = $self->getModel($model);
  
  $model->action($action, $params);
  
  $pl = {
	'model' => $model,
	'action' => $action,
	'params' => $params
	};
  
  
  #$self->pr($pl, "What have you done!?", 0);
  
  push @{$debug}, \@path_parts;
  
  foreach my $p ($self->q->param) {
	push @{$debug}, $p . ' = ' . $self->q->param($p);
  }
  $self->pr($debug);
  
}


1;