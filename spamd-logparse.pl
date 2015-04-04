#!/usr/bin/perl -w

# ex:ts=8 sw=4:

use strict;

use Data::Dumper qw(Dumper);
use Getopt::Std;
use List::MoreUtils qw(uniq);
use Geo::IP;
use RRDs;

my %opts;
my $fh_log;
my $log_file;
my @log_line;
my $ip;
my @ip_addr;
my @uip_addr;

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

while (<$fh_log>) {
	chomp;
	@log_line = split(' ', $_);
	$ip = $log_line[5];
	$ip =~ s/://;
	$_ = $ip;
	next if /^logfile/;
	push ( @ip_addr, $ip );
}
@uip_addr = uniq @ip_addr;
print Dumper \@uip_addr;
close($fh_log);
