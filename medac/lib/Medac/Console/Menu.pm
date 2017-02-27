package Medac::Console::Menu;
use lib '../..';

use Moose;

use Medac::Console::Menu::Item;
use strict;
use warnings;
use Data::Dumper;
use List::Util qw(reduce);
use Term::ANSIColor::Markup qw(colorize);

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
	default => '<white>Choose</white><yellow>:</yellow> '
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

sub colorize {
	my $self = shift @_;
	my $text = shift @_;
	return Term::ANSIColor::Markup->colorize($text);
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

sub getItem {
	my $self = shift @_;
	my $key = shift @_;
	
	foreach my $item (@{$self->items}) {
		if (lc($item->key) eq lc($key)) {
			return $item;
		}
	}
	
	return 0;
}

sub maxLen {
	my $self = shift @_;
	return $self->maxLength;
}

sub hr {
	my $len = shift @_;
	if ($len !~ m/^\d+$/) {
		$len = 40;
	}
	
	return Medac::Console::Menu->colorize("<yellow>-</yellow><blue>=</blue>" x $len);
}

sub getMenu {
	my $self = shift @_;
	
	my $mnu = '';
	$mnu .= $self->colorize('<white>' . $self->title . '</white>') . "\n";
	$mnu .= Medac::Console::Menu->hr();
	$mnu .= "\n";
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
	
	return $self->colorize($mnu);
} # getMenu()

sub display {
	my $self = shift @_;
	
	#my $accept_opts = join('|', map {$_->key =~ m/[A-Za-z]/ ? '(' . uc($_->key) . lc($_->key) : $_->key;} @{$self->items});
	my $accept_opts = join('|', map { $_->key; } @{$self->items});
	my $acceptable = '^(' . $accept_opts . ')$';
	
	my $is_acceptable = 0;
	my $answer = '';
	while (!$is_acceptable) {
		print $self->getMenu();
		print "\n";
		print $self->colorize($self->prompt());
		$answer = lc(<STDIN>);
		chomp($answer);
		
		$is_acceptable = ($answer =~ m/$acceptable/gi);
		if (!$is_acceptable) {
			print "Please choose from the list! \"$answer\"\n";
		} 
	}
	my $item = $self->getItem($answer);
	&{$item->action}();
	
	#print Dumper($item);
	
	my $ret_val = defined $self->return_vals()->{$answer} ? $self->return_vals()->{$answer} : lc($answer);
	return $ret_val;
} # display()


1;