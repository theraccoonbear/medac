package Medac::API;
#use lib '../../../medac/Medac';

use Moose;

with 'Medac';
#with 'Medac::Config';
with 'Medac::Response';

use lib '..';
use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use Medac::API::Default;
use Medac::Provider;
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



has 'initialized' => (
  is => 'rw',
  isa => 'Bool',
  default => undef
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
	
	if (defined $self->drillex($params, ['posted','provider','name'])) {
		$self->provider($self->drill($params, ['posted','provider','name']));
	}
	
	#$self->json_pr($params, "Whoa!");
	
	
	
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
} # init()

sub dispatch {
  my $self = shift @_;
  my $p_model = shift @_ || 'Default';
	my $p_action = shift @_ || 'who';;
  
	
  $self->model($p_model);
  $self->action($p_action);
	$self->init();
	
  my $model = $self->getModel($self->model());
  
  $model->action($self->action(), $self->req->{params});
} # dispatch()

1;