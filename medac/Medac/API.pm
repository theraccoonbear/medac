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
use Medac::Config;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);
use Moose::Util::TypeConstraints;


has 'model' => (
	is => 'rw',
	isa => 'Str',
	default => 'Default'
);

has 'action' => (
	is => 'rw',
	isa => 'Str',
	default => 'index'
);

has 'req' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub{ return {}; }
);

has 'initialized' => (
  is => 'rw',
  isa => 'Bool',
  default => undef
);

has 'config' => (
  is => 'rw',
  isa => 'Medac::Config',
  default => sub { my $cfg = new Medac::Config(); return $cfg; }
);

#has 'provider' => (
#	is => 'rw',
#	isa => 'Medac::Provider',
#	default => sub {
#		return new Medac::Provider;
#	}
#);

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

enum 'ContextType', [qw(local www)];

has 'context' => (
	is => 'rw',
	isa => 'ContextType',
	default => 'local'
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
	my $default = shift @_ || undef;
	
	foreach my $bit (@{$bits}) {
		if (ref $obj eq 'HASH' && defined $obj->{$bit}) {
			$obj = $obj->{$bit};
		} elsif (ref $obj eq 'ARRAY' && defined $obj->[$bit]) {
			$obj = $obj->[$bit];
		} else {
			$obj = $default;
			last;
		}
	}
	
	return $obj;
}

sub stackTrace {
	my $self = shift @_;
	
	my $max_depth = 30;
	my $i = 0;
	my $stack = [];
	
	while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
		push @{$stack}, "$i) $call_details[1] line $call_details[2] in function $call_details[3]";
	}
	
	return $stack;
}

sub pr {
	my $self = shift @_;
	my $o = shift @_;
	#my $max_depth = 30;
	
	if ($self->context eq 'www') {
		print "Content-Type: text/html\n\n";
		print '<h1>Dump:</h1>';
		print '<pre>';
	} else {
		print "Dump:\n";
	}
	print Dumper($o);
	if ($self->context eq 'www') {
		print '</pre>';
		print '<h1>Stack:</h1>';
		print '<pre>';
	} else {
		print "Stack:\n";
	}
	print join("\n", @{$self->stackTrace()});
	
	if ($self->context eq 'www') {
		print '</pre>';
	}
	exit;
}

sub json_pr {
	my $self = shift @_;
	my $o = shift @_;
	my $message = shift @_ || '';
	my $success = shift @_;
	
	if (! defined $success) {
		$success = 1 == 1;
	}
	
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
	
	
	my $tfp = __FILE__;
	
	$tfp =~ s/\/[^\/]+$//gi;
	
	my $fq_class_name = "Medac::API::$model";
	my $model_path = "$tfp/API/$model.pm";
	
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

sub init {
	my $self = shift @_;
	
	my $post_str = $self->q->param('request') || '{"provider":{"name":"providername","host":{"pass":"p4s5w0rD","user":"guest","name":"medac-provider.hostname.com","path":"/path/to/video/","port":22}},"account":{"username":"localuser","password":"localpass","host":{"name":"medac-provider.hostname.com","port":80}},"resource":{"md5":"b00d64cd31665414f6b5ebd47c2d0fba","path":"TV/Band of Brothers/Season 1/01 - Curahee.avi"}}';
	
	my $posted = decode_json($post_str);
	
  my $params = {
		'named' => {},
		'numerical' => [],
		'posted' => $posted
	};
	
  my @path_parts = split(/\//, $self->q->url_param('path') || '');
	
  my $p_cnt = scalar @path_parts;
  
  if ($p_cnt == 0) {
		$self->error("You're giving me nothin' here: " . join('/', @path_parts));
  }
	
	if ($p_cnt >= 1) {
		$self->model($self->utoc($path_parts[0]));
  }
  
  if ($p_cnt >= 2) {
		$self->action($path_parts[1]);
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
		'model' => $self->model,
		'action' => $self->action,
		'params' => $params
	};
  
	$self->req($pl);
}

sub dispatch {
  my $self = shift @_;
  
  my $debug = ();
  
  $self->model('Default');
  $self->action('Index');
	$self->init();
	
#	$self->req($pl);
	
  my $model = $self->getModel($self->model());
  
  $model->action($self->action(), $self->req->{params});
  
}


1;