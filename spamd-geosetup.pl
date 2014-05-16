#!/usr/bin/perl -w

# ex:ts=8 sw=4:

# autoflush buffer
$| = 1;

use strict;

use FindBin;
use lib ("$FindBin::Bin");

use Getopt::Std;
use LWP::UserAgent;

my $pfctl = '/sbin/pfctl';
my $spamdb = '/usr/sbin/spamdb';

my %opts;
my $config_file;
my $fh_cf;
my $proto = '';
my $file = '';
my @a_uri;
my $countp = 0;
my $countf = 0;
my $ztxt_spamfile;

getopts('hc:', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-geosetup.pl [ -c config file]\n";
        exit;
}
if ( defined $opts{'c'} ) {
	$config_file = $opts{'c'};
} else {
	$config_file = '/etc/mail/spamd.conf';
}

if ( -f $config_file ) {
	open $fh_cf, '<', $config_file or die "Can't open $config_file";
}

# Parse spamd.conf configuration file
# creates uris to grab ip addresses list files
while (<$fh_cf>) {
	chomp;
	next if /^#/;
	if ( /(.*)method=/ ) {
		$proto = $_;
		$proto =~ s/\t:method=(.*)\\/$1/;
		$proto =~ s/://;
		$a_uri[$countp]{'proto'} = $proto;
		$countp++;
	}
	if ( /(.*)file=/ ) {
		$file = $_;
		$file =~ s/\t:file=(.*)/$1/;
		$a_uri[$countf]{'file'} = $file;
		$countf++;
	}
}

for my $count ( 0 .. ( @a_uri - 1 ) ) {
	print $a_uri[$count]{'proto'} . "://" . $a_uri[$count]{'file'} . "\n";
        # Create a user agent object
        my $ua = LWP::UserAgent->new;
        $ua->agent("spamd-geosetup/0.1");

        # Create a request
        my $req = HTTP::Request->new(GET => $a_uri[$count]{'proto'} . '://' . $a_uri[$count]{'file'});

        # Pass request to the user agent and get a response back
        my $res = $ua->request($req);

        # Check the outcome of the response
        if ($res->is_success) {
                $ztxt_spamfile = $res->content;
        } else {
                die $res->status_line, "\n";
        }
}
