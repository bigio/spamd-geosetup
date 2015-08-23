#!/usr/bin/perl

# ex:ts=8 sw=4:

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Getopt::Std;
use List::MoreUtils qw(uniq);
use Geo::IP;

my %opts;
my $fh_log;
my $log_file;
my @log_line;
my $ip;
my @ip_addr;
my @uip_addr;
my $geodb='/usr/local/share/examples/GeoIP/GeoIP.dat';
my $country='';
my @geoip;
my @geostats;
my %stats;	# Count of ip per country

getopts('d:hf:g:', \%opts);
if ( defined $opts{'h'} ) {
        print "Usage: spamd-logparse.pl -f [-g]\n";
        exit;
}
if ( defined $opts{'d'} ) {
	$geodb = $opts{'d'};
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
close($fh_log);
@uip_addr = uniq @ip_addr;

my $gi = Geo::IP->open("$geodb")
                or die("Cannot open GeoIP.dat file");
for my $i ( 0 .. @uip_addr ) {
	if ( defined($uip_addr[$i]) ) {
		$country = $gi->country_code_by_addr("$uip_addr[$i]");
		# count countries
		$geostats[$i] = $country;
		# informations about ip addresses and countries
		$geoip[$i]{GEO} = $country;
		$geoip[$i]{IP} = $uip_addr[$i];
	}
}

# Create an hash to have countries that send more spam
my @sgeostats = sort @geostats;
my $j = 1;
my $soldgeostats = "";
for my $i ( 0 .. @sgeostats ) {
	if ( defined($sgeostats[$i]) && $sgeostats[$i] eq $soldgeostats ) {
		$stats{$sgeostats[$i]} = $j++;
	} else {
		$j = 1;
	}
	$soldgeostats = $sgeostats[$i];
}
# Print countries with number of spammer ip addresses
print Dumper \%stats;
