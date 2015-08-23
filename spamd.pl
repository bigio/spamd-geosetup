#!/usr/bin/perl

# ex:ts=8 sw=4:

package spamd;

use strict;
use warnings;

use Data::Dumper;
use Getopt::Std;
use base qw(Net::Server);
use Net::Server::Daemonize qw(daemonize);
use Unix::Syslog qw(:macros :subs);

my %opts = ();
my $background = 0;
my $pid;
my $port=2525;
my $listenip='*';
my $user=undef;
my $group=undef;

# Print slowly
sub slowprint {
	my $text = shift(@_);
	my $i = 0;
	for ( $i .. length($text) ) {
		print substr($text, $i, 1);
		sleep 1;
		$i++;
	}
	print "\015\012";
}

# Process smtp requests
sub process_request {
	my $self = shift;
	my $start_time = time;
	my $elapsed_time;
	# print Dumper $self;
	slowprint "220 spamd IP-based SPAM blocker";
	while (<STDIN>) {
		s/[\r\n]+$//;
		slowprint "250 spamd Hello, pleased to meet you" if /HELO.*/i;
		slowprint "250 2.0.0: Ok" if /(MAIL FROM:.*)|(RCPT TO:.*)/i;
		last if /(QUIT)|(^\.$)/i;
	}
	slowprint "221 2.0.0: Bye";
	$elapsed_time = time - $start_time;
	do_log($self->{'server'}->{'peeraddr'}, $elapsed_time);
}

sub do_log {
	my $ip_addr = shift;
	my $elapsed_time = shift;
	my $id = 'spamd.pl'; my $fac = 'mail';
	$fac =~ /^[A-Za-z0-9_]+\z/
		or die "Suspicious syslog facility name: $fac";
	my $syslog_facility_num = eval("LOG_\U$fac");
	$syslog_facility_num =~ /^\d+\z/
	or die "Unknown syslog facility name: $fac";
	openlog($id, LOG_PID | LOG_NDELAY, $syslog_facility_num);
	syslog LOG_INFO, "Spammer %s stuck for %d seconds", $ip_addr, $elapsed_time;
	closelog();
}

# option parsing
getopts('bg:p:u:', \%opts);
if ( defined $opts{'b'} ) {
	$background = 1;
	if (defined $opts{'g'} and defined $opts{'u'} ) {
		$user=$opts{'u'};
		$group=$opts{'g'};
	} else {
		die("Background mode needs user [-u] and group [-g] parameters");
	}
}

# Set a port different from default
if ( defined $opts{'p'} ) {
	$port = $opts{'p'};
}

# Daemonize if requested
if ($background eq 1) {
	daemonize(
	$user,
	$group,
	$pid
	);
}
spamd->run(port => $port, ipv => $listenip);
1;
