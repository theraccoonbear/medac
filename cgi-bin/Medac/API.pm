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


has 'req' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub{ return {}; }
);

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

sub drillex {
	my $self = shift @_;
	my $obj = shift @_;
	my $bits = shift @_;
	my $default = '____________MISSING';
	
	my $val = $self->drill($obj, $bits, $default);
	
	return $val ne $default;	
}

sub drill {
	my $self = shift @_;
	my $obj = shift @_;
	my $bits = shift @_;
	my $default = shift @_ || 1 == 0;
	
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


sub pr {
	my $self = shift @_;
	my $o = shift @_;
	my $max_depth = 30;
	
	print "Content-Type: text/html\n\n";
	print '<h1>Dump:</h1>';
	print '<pre>';
	print Data::Dumper::Dumper($o);
	print '</pre>';
	print '<h1>Stack:</h1>';
	print '<pre>';
	my $i = 0;
	while ( (my @call_details = (caller($i++))) && ($i<$max_depth)) {
		print "$i) $call_details[1] line $call_details[2] in function $call_details[3]\n";
	}
	print '</pre>';
	exit;
}

sub json_pr {
	my $self = shift @_;
	my $o = shift @_;
	my $message = shift @_ || '';
	my $success = shift @_;
	
	if ($message eq '') {
		$message = $success ? 'Call successful' : 'Call failed';
	}
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
	
	$self->json_pr({}, $msg, 1 == 0);
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
	my $model = shift @_;
	
	if ($model =~ m/[^A-Za-z_]/gi) {
		$self->error("Invalid model name: $model");
	}
	
	
	
	my $fq_class_name = "Medac::API::$model";
	my $model_path = "Medac/API/$model.pm";
	
	my $ci = {};
	
	
	if (-f $model_path) {
	
		require $model_path;
		$ci = new $fq_class_name();
		
		if (!$ci->isa($fq_class_name)) {
			$self->error("Unable to instantiate: $fq_class_name");
		}
		
		$ci->req($self->req);
	} else {
		$self->error("Could not find model: $model");
	}
	
	return $ci;
}

sub dispatch {
  my $self = shift @_;
  
  my $debug = ();
  
  my $model = 'Default';
  my $action = 'Index';
	
	#my $post_str = $self->q->param('request') || '{}';
	my $post_str = $self->q->param('request') || '{"provider":{"name":"providername","host":{"pass":"p4s5w0rD","user":"guest","name":"medac-provider.hostname.com","path":"/path/to/video/","port":22}},"account":{"username":"localuser","password":"localpass","host":{"name":"medac-provider.hostname.com","port":80}},"resource":{"md5":"b00d64cd31665414f6b5ebd47c2d0fba","path":"TV/Band of Brothers/Season 1/01 - Curahee.avi"}}';
	
	my $posted = decode_json($post_str);
	
  my $params = {
		'named' => {},
		'numerical' => [],
		'posted' => $posted
	};
	
  my @path_parts = split(/\//, $self->q->url_param('path'));

	
  my $p_cnt = scalar @path_parts;
  
  if ($p_cnt == 0) {
		$self->error("You're giving me nothin' here: " . join('/', @path_parts));
  }
	
	if ($p_cnt >= 1) {
		$model = $self->utoc($path_parts[0]);
  }
  
  if ($p_cnt >= 2) {
		$action = $path_parts[1];
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
  
	$self->req($pl);
	
  $model = $self->getModel($model, $pl);
  
  $model->action($action, $params);
  
}


1;