package Medac::Misc::Menu;
use lib '../..';

use Moose;

use Medac::Misc::Menu::Item;
use strict;
use warnings;
use Data::Dumper;

has 'title' => (
	is => 'rw',
	isa => 'Str',
	default => 'Menu'
);

has 'items' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { [] }
);

my $maxLength = 0;

sub addItem {
	my $self = shift @_;
	my $o = shift @_;
	$o->menu($self);
	my $len = length($o->key);
	$maxLength = $len > $maxLength ? $len : $maxLength;
	push @{$self->items}, $o;
} # addOption()

sub maxLen {
	my $self = shift @_;
	return $maxLength;
}


sub getMenu {
	my $self = shift @_;
	
	my $mnu = '';
	$mnu .= $self->title . "\n";
	$mnu .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
	foreach my $item (@{$self->items}) {
		$mnu .= $item->getEntry() . "\n";
	}
	return $mnu;
} # display()


1;