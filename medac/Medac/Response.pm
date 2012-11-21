package Medac::Response;

use Moose::Role;

with 'Medac::Config';

use lib '..';
use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use Slurp;
use CGI;
use POSIX;
use Medac::API::Default;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use Cwd qw(abs_path cwd);
use Moose::Util::TypeConstraints;

enum 'ContextType', [qw(local www)];

has 'context' => (
	is => 'rw',
	isa => 'ContextType',
	default => 'local'
);

sub stackTrace {
	my $self = shift @_;
	
	my $max_depth = 30;
	my $i = 0;
	my $stack = [];
	
	while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
		push @{$stack}, "$i) $call_details[1] line $call_details[2] in function $call_details[3]";
	}
	
	return $stack;
}

sub pr {
	my $self = shift @_;
	my $o = shift @_;
	#my $max_depth = 30;
	
	if ($self->context eq 'www') {
		print "Content-Type: text/html\n\n";
		print '<h1>Dump:</h1>';
		print '<pre>';
	} else {
		print "Dump:\n";
	}
	print Dumper($o);
	if ($self->context eq 'www') {
		print '</pre>';
		print '<h1>Stack:</h1>';
		print '<pre>';
	} else {
		print "Stack:\n";
	}
	print join("\n", @{$self->stackTrace()});
	
	if ($self->context eq 'www') {
		print '</pre>';
	}
	exit;
}

sub json_pr {
	my $self = shift @_;
	my $o = shift @_;
	my $message = shift @_ || '';
	my $success = shift @_;
	
	if (! defined $success) {
		$success = 1 == 1;
	}
	
	if ($message eq '') {
		$message = $success ? 'Call successful' : 'Call failed';
	}
	$success = $success ? JSON::XS::true : JSON::XS::false;
	
	my $json = encode_json({
		'success' => $success,
		'payload' => $o,
		'message' => $message
	});
	
	# print "Content-Type: application/x-json\n\n";
	print "Content-Type: text/plain\n\n";
	print $json;
	exit;
}

sub error {
	my $self = shift @_;
	my $msg = shift @_ || "Unknown error";
	
	$self->json_pr({}, $msg, 1 == 0);
}

1;