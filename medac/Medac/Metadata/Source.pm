package Medac::Metadata::Source;
use lib '../..';

use Moose;

use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein qw(distance);
use Mojo::DOM;
use Medac::Cache;
use URI::Escape;

has 'mech' => (
	'is' => 'rw',
	'isa' => 'WWW::Mechanize',
	'default' => sub {
		my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
		my $cookie_jar = HTTP::Cookies->new();
		$cookie_jar->clear();
		my $www_mech = WWW::Mechanize->new(
			cookie_jar => $cookie_jar
		);
		$www_mech->agent($ua_string);
		return $www_mech;
	}
);

sub pullURL {
	my $self = shift @_;
	my $url = shift @_;
	
	my $ret = {
		success => 0,
		content => ''
	};
	
	$self->mech->get($url);
	if ($self->mech->success) {
		$ret->{success} = 1;
		$ret->{content} = $self->mech->{content};
	}
	
	return $ret;
}

sub objDrill {
	my $self = shift @_;
	my $obj = shift @_;
	my $drill = shift @_;
	
	foreach my $i (@$drill) {
		if (defined $obj->{$i}) {
			$obj = $obj->{$i}
		} else {
			return undef;
		}
	}
	
	return $obj;
}

sub dist {
	my $self = shift @_;
	my $val_1 = shift @_;
	my $val_2 = shift @_;
	
	# normalize...
	$val_1 = lc($val_1);
	$val_2 = lc($val_2);
	$val_1 =~ s/\&/and/gi;
	$val_2 =~ s/\&/and/gi;
	$val_1 =~ s/^\s*(.+?)\s*$/$1/gi;
	$val_2 =~ s/^\s*(.+?)\s*$/$1/gi;
	$val_1 =~ s/\s{2,}/ /gi;
	$val_2 =~ s/\s{2,}/ /gi;
	
	return distance($val_1, $val_2);
}

1;