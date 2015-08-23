#!/usr/bin/perl

#------------------------------------------------------------------------------
# Copyright (c) 2014, Giovanni Bechis
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#------------------------------------------------------------------------------

# ex:ts=8 sw=4:

# autoflush buffer
$| = 1;

use strict;
use warnings;

use FindBin;
use lib ("$FindBin::Bin");

use Getopt::Std;
use List::MoreUtils qw(uniq);
use LWP::UserAgent;
use File::Temp qw/ :mktemp /;
use File::LibMagic 1.11;
use Geo::IP;

my $pfctl = '/sbin/pfctl';
my $ipset = '/usr/sbin/ipset';
my $spamdb = '/usr/sbin/spamdb';
my $gzip = '/usr/bin/gzip';
my $config_file = '/etc/mail/spamd.conf';
my $geospamdb = '';

my $version = '0.2';
my %opts;
my $gs_config_file;
my $offline = 0;
my $quiet = 0;
my $spamfile = '';
my $fh_cf;
my $fh_zs;
my $proto = '';
my $file = '';
my $white_country = '';
my @a_uri;
my $countf = 0;
my $countp = 0;
my $zfinfo;
my $ztxt_spamfile;
my $ip;
my $all_ip = '';

getopts('c:hoq', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-geosetup.pl [ -c config file] [-o] [-q]\n";
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

if ( defined $opts{'q'} ) {
	$quiet = 1;
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
		$file =~ s/://;
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
	if ( /(.*)geospamdb=/ ) {
		$geospamdb = $_;
		$geospamdb =~ s/geospamdb=(.*)/$1/;
	}
}
close($fh_cf);

my $gi = Geo::IP->open("$geospamdb") 
		or die("Cannot open GeoIP.dat file");
my $country = '';
for my $count ( 0 .. ( @a_uri - 1 ) ) {
	if ( !$quiet ) {
		print $a_uri[$count]{'proto'} . "://" . $a_uri[$count]{'file'} . "\n";
	}
	# Used to determine if the file is correctly downloaded
	my $magic = File::LibMagic->new();
	if ( !$offline ) {
        	# Create a user agent object
        	my $ua = LWP::UserAgent->new;
        	$ua->agent("spamd-geosetup/$version");

        	# Create a request
        	my $req = HTTP::Request->new(GET => $a_uri[$count]{'proto'} . '://' . $a_uri[$count]{'file'});

        	# Pass request to the user agent and get a response back
        	my $res = $ua->request($req);

        	# Check the outcome of the response
        	if ($res->is_success) {
                	$ztxt_spamfile = $res->content;
			$spamfile = mktemp( "/tmp/spamXXXXXXX" );
			open $fh_zs, '>', $spamfile or die("Cannot write downloaded file $a_uri[$count]{'file'}\n");
			print $fh_zs $ztxt_spamfile;
			close($fh_zs);
			if ( -B $spamfile ) {
				$zfinfo = $magic->info_from_filename($spamfile);
				if ( $zfinfo->{mime_type} eq "application/x-gzip" ) {
					open $fh_zs, "$gzip -dc $spamfile|" or die("Cannot open $spamfile");
				} else {
					# File has not been correctly downloaded
					exit 1;
				}	
			} else {
				open $fh_zs, "$spamfile" or die("Cannot open $spamfile");
			}
        	} else {
                	die $res->status_line, "\n";
        	}
	} else {
		my @a_spamfile = split('/', $a_uri[$count]{'file'});
		$spamfile = $a_spamfile[@a_spamfile - 1];
		if ( -f $spamfile ) {
			if ( -B $spamfile ) {
				$zfinfo = $magic->info_from_filename($spamfile);
				if ( $zfinfo->{mime_type} eq "application/x-gzip" ) {
					open $fh_zs, "$gzip -dc $spamfile|" or die("Cannot open $spamfile");
				} else {
					# File is malformed
					exit 1;
				}
			} else {
				open $fh_zs, "$spamfile" or die("Cannot open $spamfile");
			}
		} else {
			# Errors out and skip this file
			if ( !$quiet ) {
				print "File $spamfile not found\n";
			}
			next;
		}
	}
	while (<$fh_zs>) {
		$ip = $_;
		chomp;
		next if /^#/;
		$ip =~ s/\/(.*)//;
		chop($ip);
		$country = $gi->country_code_by_addr("$ip");
		if ( defined ( $country ) && $country !~ /$white_country/ ) {
			$all_ip .= $ip . "\n";
		}		
	}	
	close($fh_zs);
	if ( !$offline ) {
		unlink($spamfile);
	}
}
# Run pfctl/ipset only if we are root
if ( $> eq 0 ) {
	if ( defined $all_ip ) {
		if ( $^O =~ /linux/ ) {
			my @ips = uniq split("\n", $all_ip);
			system("$ipset flush spamd");
			foreach my $spam_ip (@ips) {
				if ( $spam_ip !~ m/([a-zA-Z])/ ) {
					system("$ipset add spamd $spam_ip");
				}
			}
		} else {
			# Flush spamd table if we are root
			if ( $all_ip !~ m/([a-zA-Z])/ ) {
				system("$pfctl -q -t spamd -T flush");
				open(SY, "| $pfctl -q -t spamd -T add -f - ");
				print SY $all_ip;
				close(SY);
			}
		}
	} else {
		if ( !$quiet ) {
			print "empty ip list, cannot run firewall program\n";
		}
	}
} else {
	die("Cannot run firewall program, are you root?\n");
}
