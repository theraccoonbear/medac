package Medac::Cache;

use Moose;
use Data::Dumper;
use JSON::XS;
use Digest::MD5 qw(md5 md5_hex);
use File::Slurp;
use Cwd qw(abs_path cwd);
use Cache::FileCache;

my $cache = new Cache::FileCache({
	'namespace' => 'Plex',
	'default_expires_in' => 600
});


has 'context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'basic'
);

#has 'cache' => (
#  'is' => 'rw',
#	'isa' => 'HashRef',
#	'default' => sub {
#		my $self = shift @_;
#		my $d_cache = $self->readDiskCache();
#		return $d_cache;
#	}
#);

has 'cache' => (
  'is' => 'rw',
	'isa' => 'Cache::FileCache',
	'default' => sub {
		my $self = shift @_;
		my $d_cache = new Cache::FileCache({
			'namespace' => 'Medac',
			'default_expires_in' => 600
		});
		#$d_cache->clear();
		return $d_cache;
	}
);

sub keyCalc {
  my $self = shift @_;
  my $name = shift @_;

  return $self->context . '::' . $name;  
  #return md5_hex($name);
}

sub hit {
  my $self = shift @_;
  my $name = shift @_;
  my $key = $self->keyCalc($name);
	#return 0;
	return defined $self->cache->get($key) ? 1 : 0;
}

sub getVal {
	my $self = shift @_;
	my $name = shift @_;
	my $key = $self->keyCalc($name);
	return $self->cache->get($key);
}

sub retrieve {
  my $self = shift @_;  
  my $name = shift @_;
  my $key = $self->keyCalc($name);
	
  if ($self->hit($name)) {
    return $self->getVal($key);
  } else {
    return {};
  }
}

sub store {
  my $self = shift @_;
  
  my $name = shift @_;
  my $value = shift @_;
	my $key = $self->keyCalc($name);

  $self->cache->set($key, $value);
}


1;