package Medac::Response;

use Moose::Role;

use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};

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


sub stackTrace {
	my $self = shift @_;
	
	my $max_depth = 30;
	my $i = 1;
	my $stack = [];
	
	
	my $cnt = 0;
	while ((my @call_details = (caller($i++))) && ($i<$max_depth)) {
		$cnt++;
		push @{$stack}, "$cnt) $call_details[1] line $call_details[2] in function $call_details[3]";
	}
	
	return $stack;
}

sub pr {
	my $self = shift @_;
	my $o = shift @_;
	
	if (IS_CGI) {
		print "Content-Type: text/html\n\n";
		print '<h1>Dump:</h1>';
		print '<pre>';
	} else {
		print "Dump:\n";
	}
	print Dumper($o);
	
	if (IS_CGI) {
		print '</pre>';
		print '<h1>Stack:</h1>';
		print '<pre>';
	} else {
		print "Stack:\n";
	}
	print join("\n", @{$self->stackTrace()});
	
	if (IS_CGI) {
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
	my $obj = shift @_;
	
	if (IS_CGI) {
		$self->json_pr({stacktrace => $self->stackTrace(), object => $obj}, $msg, 1 == 0);
	} else {
		$self->pr("ERROR: $msg");
	}
}

1;