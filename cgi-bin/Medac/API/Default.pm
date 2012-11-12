package Medac::API::Default;
#use lib '../../../medac/Medac';

use Moose;



extends 'Medac::API';

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

sub action {
  my $self = shift @_;
  my $action = shift @_;
  my $params = shift @_;
  
  my $class_name = ref($self);
  
  $self->pr(defined $class_name);
  
  my $debug = '';
  no strict 'refs';
  for(keys %Foo::) { # All the symbols in Foo's symbol table
    $debug .= "$_\n" if defined &{$_}; # check if symbol is method
  }
  use strict 'refs';
  
  $self->pr($debug);
  
  #$self->pr(&{$action});
  #$self->$action($params);
  #my $fnc = 'action';
  #$self->pr(defined &{$self->$fnc});
  #$self->pr(defined &{$action});
  
  if (defined $self->{$action}) {
    #$self->pr($self->$action());
    $self->$action($params);
  } else {
    $self->pr($self, $action);
    $self->error('Unknown action: ' . $action);
  }
}

1;