#!/usr/bin/perl
use strict;
use warnings;
use JSON::XS;
use File::Slurp;
use Data::Dumper;
use API;
use Slurp;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);

my $q = CGI->new();

my $config = decode_json(slurp('../medac/config.json'));

print "Content-Type: text/plain\n\n";

sub pr {
	my $o = shift @_;
	
	print '<pre>';
	print Data::Dumper::Dumper($o);
	print '</pre>';
}

sub json_pr {
	my $o = shift @_;
	my $json = encode_json({
		'success' => JSON::XS::true,
		'payload' => $o
		});
	
	print $json;
}

sub user_group {
	my @groups = split '\s', $(;
	my $gr = [];
	foreach my $g (@groups) {
		push @{$gr}, getgrgid($g);
	}
	
	my $uinfo = {
		'root' => $< == 0 ? JSON::XS::true : JSON::XS::false,
		'user' => (getpwuid($<))[0],
		'groups' => $gr
	};
	
	json_pr($uinfo);
	exit;	
}
#user_group();

my $req_str = defined $q->param('request') ? $q->param('request') : '{"provider":{"name":"theraccoonbearcity","host":{"pass":"gu35t!","user":"guest","name":"medac-dev.snm.com","path":"/home/don/Desktop/Video/","port":22}},"account":{"username":"g33k","password":"qwerty","host":{"name":"medac-dev.snm.com","port":80}},"resource":{"md5":"b00d64cd31665414f6b5ebd47c2d0fba","path":"TV/Band of Brothers/Season 1/01 - Curahee.avi"}}';

my $request = decode_json($req_str);


my $queue_dir = 'queue/' . $request->{provider}->{name};
my $dl_path = $config->{paths}->{downloads} . $request->{provider}->{name} . '/';

if (! -d $dl_path) {
	mkdir $dl_path, 0775 or die $!;
}


if (! -d $queue_dir) {
	mkdir $queue_dir;
}
my $queue_path = $queue_dir . '/queue.txt';

my $file = $request->{resource}->{path};
my $msg = '';
my @FILES = (); 

if (-f $queue_path) {
	my $queue_list_str = read_file($queue_path);
	@FILES = split(/\n/, $queue_list_str);
}

my $in_queue = 0;
my $size = 0;
foreach my $f (@FILES) {
	my $f_dl_path = $dl_path . $f;
	
	if (-f $f_dl_path) {
		$size = (stat $f_dl_path)[7];
	}
	
	if ($f eq $file) {
		$in_queue = 1;
		last;
	}
}

if (! $in_queue) {
	push @FILES, $file;
	write_file($queue_path, join("\n", @FILES));
	$msg = "File added to download queue";
} else {
	$msg = "File already in queue";
}

my $rsync_cmd = <<__RSYNC;
rsync -avz --progress --partial --append --files-from $queue_path -e "ssh -p $request->{provider}->{host}->{port}" $request->{provider}->{host}->{user}\@$request->{provider}->{host}->{name}:$request->{provider}->{host}->{path} $config->{paths}->{downloads}$request->{provider}->{name}
__RSYNC

#print $rsync_cmd; exit;

my $output = `$rsync_cmd`;

my $resp = {
	'added' => $in_queue ? JSON::XS::false : JSON::XS::true,
	'message' => $msg,
	'size' => $size,
	'output' => $output,
	'cmd' => $rsync_cmd
};

json_pr($resp);
