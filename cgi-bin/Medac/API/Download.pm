package Medac::API::Download;
#use lib '../../../medac/Medac';

use Moose;

extends 'Medac::API::Default';

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

sub status {
  my $self = shift @_;
  my $params = shift @_;
  
  $self->pr($self->config);
  
  if ($params->{named}->{path}) {
    my $file = $params->{named}->{path};
    
    if (-f $file) {
      
    } else {
      
    }
  } else {
    $self->error("No path supplied");
  }
  
}

1;