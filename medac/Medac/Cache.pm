package Medac::Cache;

use Moose;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex);

has '_cache' => (
  'is' => 'rw',
  'isa' => 'HashRef[HashRef[Str]xasda]'
);

#my $_cache = {};

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
  
  if (! defined $self->_cache) {
    #$self->_cache = {};  
  }
  print Dumper($self);
  #if (!defined $self->_cache{$context}) {
  #  
  #}

}

sub cache {
  my $self = shift @_;
  
  my $context = 'unknown';
  my $name = 'name';
  my $key = $self->keyCalc($name);
  my $value = {};
  my @CALLER = caller();
  
  if (scalar @_ == 3) {
    $context = shift @_;
  }
  
  $name = shift @_;
  $value = shift @_;  
  
  my $cache_rep = 'cache/' . $CALLER[0] . '.cache';
  
  print "Store In: $cache_rep\n";
  print "Name: $name\n";
  print "Key: $key\n";
  print Dumper($value);
  
  $self->setVal($context, $name, $value);
  
  
  exit(0);
}

1;