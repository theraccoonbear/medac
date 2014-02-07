package Medac::Misc::Menu::Item;
use lib '../../..';

use Moose;

use strict;
use warnings;
use Data::Dumper;

has 'label' => (
	is => 'rw',
	isa => 'Str'
);

has 'key' => (
	is => 'rw',
	isa => 'Str'
);

has 'menu' => (
	is => 'rw',
	isa => 'Medac::Misc::Menu',
	default => sub { return new Medac::Misc::Menu(); }
);

has 'action' => (
	is => 'rw',
	default => sub { return sub {}; }
);

sub getEntry {
	my $self = shift @_;
	my $max = $self->menu->maxLen();
	return sprintf('%0' . $max . 's', $self->key) . ') ' . $self->label;
}



1;