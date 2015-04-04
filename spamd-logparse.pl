#!/usr/bin/perl -w

# ex:ts=8 sw=4:

use strict;

use Getopt::Std;
use File::Temp qw/ :mktemp /;
use Geo::IP;
use RRDs;

my %opts;
my $fh_log;
my $log_file;

getopts('hf:g:', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-logparse.pl -f [-g]\n";
        exit;
}
if ( not defined $opts{'f'} ) {
	print "log file parameter [-f] is missing\n";
	exit;
} else {
	$log_file = $opts{'f'};
}
if ( -f $log_file ) {
        open $fh_log, '<', $log_file;
} else {
	die "Can't open $log_file"
}
close($fh_log);
