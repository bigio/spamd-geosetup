#!/usr/bin/perl -w

# ex:ts=8 sw=4:

# autoflush buffer
$| = 1;

use strict;

use FindBin;
use lib ("$FindBin::Bin");

use Getopt::Std;
use LWP::UserAgent;
use File::Temp qw/ :mktemp /;
use Geo::IP;

my $pfctl = '/sbin/pfctl';
my $spamdb = '/usr/sbin/spamdb';
my $gzip = '/usr/bin/gzip';
my $config_file = '/etc/mail/spamd.conf';
# XXX should be configurable
my $geospamdb = '/usr/local/share/examples/GeoIP/GeoIP.dat';

my %opts;
my $gs_config_file;
my $offline = 0;
my $spamfile = '';
my $fh_cf;
my $fh_zs;
my $proto = '';
my $file = '';
my $white_country = '';
my @a_uri;
my $countf = 0;
my $countp = 0;
my $ztxt_spamfile;
my $ip;

getopts('c:ho', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-geosetup.pl [ -c config file] [-o]\n";
        exit;
}
if ( defined $opts{'c'} ) {
	$gs_config_file = $opts{'c'};
} else {
	$gs_config_file = '/etc/mail/geospamd.conf';
}
if ( defined $opts{'o'} ) {
	# Offline mode
	$offline = 1;
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
close($fh_cf);

# Parse geospamd config file
if ( -f $gs_config_file ) {
        open $fh_cf, '<', $gs_config_file or die "Can't open $gs_config_file";
} else {
	die("Cannot open config file $gs_config_file");
}
while (<$fh_cf>) {
	chomp;
	next if /^#/;
	if ( /(.*)whitelist=/ ) {
		$white_country = $_;
		$white_country =~ s/whitelist=(.*)/$1/;
	}	
}
close($fh_cf);

# Flush spamd table if we are root
if ( $> eq 0 ) {
	system("$pfctl -q -t spamd -T flush");
}

my $gi = Geo::IP->open("$geospamdb") 
		or die("Cannot open GeoIP.dat file");
my $country = '';
for my $count ( 0 .. ( @a_uri - 1 ) ) {
	print $a_uri[$count]{'proto'} . "://" . $a_uri[$count]{'file'} . "\n";
	if ( !$offline ) {
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
			$spamfile = mktemp( "/tmp/spamXXXXXXX" );
			open $fh_zs, '>', $spamfile or die("Cannot uncompress downloaded file $a_uri[$count]{'file'}\n");
			print $fh_zs $ztxt_spamfile;
			close($fh_zs);
			open $fh_zs, "$gzip -dc $spamfile|" or die("Cannot open $spamfile");
        	} else {
                	die $res->status_line, "\n";
        	}
	} else {
		my @a_spamfile = split('/', $a_uri[$count]{'file'});
		$spamfile = $a_spamfile[@a_spamfile - 1];
		if ( -f $spamfile ) {
			open $fh_zs, "$gzip -dc $spamfile|" or die("Cannot open $spamfile");
		} else {
			# Errors out and skip this file
			print "File $spamfile non trovato\n";
			next;
		}
	}
	# Run pfctl only if we are root
	if ( $> eq 0 ) {
		while (<$fh_zs>) {
			$ip = $_;
			chomp;
			next if /^#/;
			$ip =~ s/\/(.*)//;
			chop($ip);
			$country = $gi->country_code_by_addr("$ip");
			if ( defined ( $country ) && $country !~ /$white_country/ ) {
				system($pfctl . " -q -t spamd -T add " . $ip);
			}		
		}	
	} else {
		die("Cannot run pfctl, are you root?\n");
	}
	close($fh_zs);
	if ( !$offline ) {
		unlink($spamfile);
	}
}
