#!/usr/bin/perl -w

# ex:ts=8 sw=4:

use strict;

use Getopt::Std;
use File::Temp qw/ :mktemp /;
use Geo::IP;
use RRDs;

my %opts;

getopts('hf:g:', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-logparse.pl -f [-g]\n";
        exit;
}
if ( not defined $opts{'f'} ) {
	print "log file parameter [-f] is missing\n";
	exit;
}
