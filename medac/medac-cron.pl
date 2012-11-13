#!/usr/bin/perl
use strict;
use warnings;

my $ps = `ps aux`;
my $rsync_tag = 'MEDAC_RSYNC_ACTIVE';

if ($ps =~ m/$rsync_tag/g) {
    print "instance in progress, exiting.\n";
    exit 0;
} else {
    my $cmd = 'echo "' . $rsync_tag . '" && rsync -avz --progress --partial --append --files-from /home/don/code/theraccoonshare.com/public_html/medac-dev/cgi-bin/queue/theraccoonbearcity/queue.txt -e "ssh -p 22" guest@medac-dev.snm.com:/home/don/Desktop/Video/ /home/don/Desktop/MedacDownloads/theraccoonbearcity';
    `$cmd`;
    print "\n\nrsync completed.\n";
    exit 0;
}
