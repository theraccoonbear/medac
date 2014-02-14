package Medac::Console::Menu;
use lib '../..';

use Moose;

use Medac::Console::Menu::Item;
use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);

has 'title' => (
	is => 'rw',
	isa => 'Str',
	default => 'Menu'
);

has 'post' => (
	is => 'rw',
	isa => 'Str',
	default => ''
);

has 'prompt' => (
	is => 'rw',
	isa => 'Str',
	default => 'Choose: '
);

has 'no_exit' => (
	is => 'rw',
	isa => 'Bool',
	default => 0
);

has 'items' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { [] }
);

has 'indent' => (
	is => 'rw',
	isa => 'Int',
	default => 4
);

has 'return_vals' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub { {} }
);

has 'maxLength' => (
	is => 'rw',
	isa => 'Int',
	default => 0
);


sub BUILD {
	my $self = shift @_;
	if (!$self->no_exit) {
		$self->addItem(new Medac::Console::Menu::Item(key => 'X', label => 'Exit', menu => $self));
	}
}

sub addItem {
	my $self = shift @_;
	my $o = shift @_;
	$o->menu($self);
	my $len = length($o->key);
	$self->maxLength($len > $self->maxLength ? $len : $self->maxLength);
	$self->return_vals()->{lc($o->key)} = defined $o->returns && length($o->returns) > 0 ? $o->returns : lc($o->key);
	push @{$self->items}, $o;
	
} # addOption()

sub maxLen {
	my $self = shift @_;
	return $self->maxLength;
}


sub getMenu {
	my $self = shift @_;
	
	my $mnu = '';
	$mnu .= $self->title . "\n";
	$mnu .= "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n";
	my $exit_item = 0;
	foreach my $item (@{$self->items}) {
		if (lc($item->key) ne 'x') {
			$mnu .= $item->getEntry() . "\n";
		} else {
			$exit_item = $item;
		}
	}
	
	if ($exit_item) {
		$mnu .= $exit_item->getEntry() . "\n";
	}
	
	$mnu .= $self->post() ? "\n" . $self->post() . "\n" : '';
	
	return $mnu;
} # getMenu()

sub display {
	my $self = shift @_;
	
	my $accept_opts = join('', map {$_->key =~ m/[A-Za-z]/ ? uc($_->key) . lc($_->key) : $_->key;} @{$self->items});
	my $acceptable = '^[' . $accept_opts . ']$';
	
	my $is_acceptable = 0;
	my $answer = '';
	while (!$is_acceptable) {
		print $self->getMenu();
		print "\n";
		print $self->prompt();
		$answer = lc(<STDIN>);
		chomp($answer);
		
		$is_acceptable = ($answer =~ m/$acceptable/gi);
		if (!$is_acceptable) {
			print "Please choose from the list! \"$answer\"\n";
		} 
	}
	my $ret_val = defined $self->return_vals()->{$answer} ? $self->return_vals()->{$answer} : lc($answer);
	return $ret_val;
} # display()


1;