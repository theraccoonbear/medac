package Medac::Cache;

use Moose;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex);
use Slurp;

#has '_cache' => (
#  'is' => 'rw',
#  'isa' => 'HashRef'
#);

my $_cache = {};

sub keyCalc {
  my $self = shift @_;
  my $name = shift @_;
  
  return md5_hex($name);
}

sub setVal {
  my $self = shift @_;
  my $context = shift @_;
  my $key = shift @_;
  my $val = shift @_;
  
  #print Dumper($self->_cache);
  
  if (! defined $_cache) {
    $_cache = {};  
  }
  if (! defined $_cache->{$context}) {
    $_cache->{$context} = {};
  }
  
  $_cache->{$context}->{$key} = $val;
}

sub hit {
  my $self = shift @_;
  my $context = 'unknown';
  my $name = 'name';
  
  my $ret_val = 0;
  
  if (scalar @_ == 2) {
    $context = shift @_;
  }
  
  $name = shift @_;
  
  my $key = $self->keyCalc($name);
  
  
  if (defined $_cache->{$context}) {
    if (defined $_cache->{$context}->{$key}) {
      $ret_val = 1;
    }
  }
  
  return $ret_val;
}

sub getVal {
  my $self = shift @_;
  
  my $context = 'unknown';
  my $name = 'name';
  
  my $ret_val = 0;
  
  if (scalar @_ == 2) {
    $context = shift @_;
  }
  
  $name = shift @_;
  my $key = $self->keyCalc($name);
  
  return $_cache->{$context}->{$key};
}

sub get {
  my $self = shift @_;
  
  my $context = 'unknown';
  my $name = 'name';
  
  my $ret_val = 0;
  
  if (scalar @_ == 2) {
    $context = shift @_;
  }
  
  $name = shift @_;
  
  if ($self->hit($context, $name)) {
    return $self->getVal($context, $name);
  } else {
    return {};
  }
}

sub cache {
  my $self = shift @_;
  
  my @CALLER = caller();
  
  my $context = 'UNKNOWN';
  
  if (scalar @_ == 3) {
    $context = shift @_;
  }
  
  my $name = shift @_;
  my $value = shift @_;
  
  my $key = $self->keyCalc($name);
  
  my $cache_rep = 'cache/' . $CALLER[0] . '.cache';

  $self->setVal($context, $key, $value);
}

sub dump {
  print Dumper($_cache);
}

1;