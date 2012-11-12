package Medac::Cache;

use Moose;
use Data::Dumper;
use JSON::XS;
use Digest::MD5 qw(md5 md5_hex);
use File::Slurp;
use Cwd qw(abs_path cwd);

has 'context' => (
	'is' => 'rw',
	'isa' => 'Str',
	'default' => 'basic'
);

has 'cache' => (
  'is' => 'rw',
	'isa' => 'HashRef',
	'default' => sub {
		my $self = shift @_;
		my $d_cache = $self->readDiskCache();
		return $d_cache;
	}
);

sub keyCalc {
  my $self = shift @_;
  my $name = shift @_;

  return $name;  
  return md5_hex($name);
}

sub cacheFile() {
	my $self = shift @_;
	my $mod_path = abs_path(__FILE__);
	$mod_path =~ s/\/[^\/]+$//gi;
	
	my $path = $mod_path . '/Cache/' . $self->keyCalc($self->context) . '.dat';
	return $path;
}

sub readDiskCache() {
	my $self = shift @_;
	my $cache_file = shift @_ || $self->cacheFile(); #'Cache/' . $self->keyCalc($ctxt) . '.dat';
	my $ret_val = {};
	if (-f $cache_file) {
		$ret_val = decode_json(read_file($cache_file));
	}
	
	return $ret_val
}

sub writeDiskCache() {
	my $self = shift @_;
	#my $ctxt = $self->context;
	my $cache_file = shift @_ || $self->cacheFile(); #'Cache/' . $self->keyCalc($ctxt) . '.dat';
	write_file($cache_file, encode_json($self->cache));
	return 1;
}

sub setVal {
  my $self = shift @_;
  my $name = shift @_;
  my $val = shift @_;
  my $key = $self->keyCalc($name);
  
  $self->cache->{$key} = $val;
  $self->writeDiskCache();
}

sub hit {
  my $self = shift @_;
  my $name = shift @_;
  
  my $key = $self->keyCalc($name);
	
  my $ret_val = 0;
  if (defined $self->cache->{$key}) {
    $ret_val = 1;
  }  
  return $ret_val;
}

sub getVal {
  my $self = shift @_;
  
  my $name = shift @_;
  my $key = $self->keyCalc($name);
  
  return $self->cache->{$key};
}

sub retrieve {
  my $self = shift @_;
  
  my $name = shift @_;
  
  if ($self->hit($name)) {
    return $self->getVal($name);
  } else {
    return {};
  }
}

sub store {
  my $self = shift @_;
  
  my $name = shift @_;
  my $value = shift @_;
  
  my $key = $self->keyCalc($name);

  $self->setVal($key, $value);
}

sub dump {
  my $self = shift @_;
  print Dumper($self->cache);
  return;
}

1;