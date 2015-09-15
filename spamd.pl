#!/usr/bin/perl

#------------------------------------------------------------------------------
# Copyright (c) 2015, Giovanni Bechis
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

package spamd;

use strict;
use warnings;

use Data::Dumper;
use Getopt::Std;
use base qw(Net::Server::PreFork);
use Net::Server::Daemonize qw(daemonize);
use Unix::Syslog qw(:macros :subs);

my %opts = ();
my $daemonize = 0;
my $pid;
my $port=2525;
my $listenip='*';
my $user=undef;
my $group=undef;
my $timeout=300;

# Print slowly
sub slowprint {
	my $text = shift(@_);
	my $i = 0;
	for ( $i .. length($text) ) {
		print substr($text, $i, 1);
		sleep 2;
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

	local $SIG{'ALRM'} = sub { do_log_and_die($self->{'server'}->{'peeraddr'}, undef, "Timed out") };
	my $previous_alarm = alarm($timeout);

	do_log($self->{'server'}->{'peeraddr'}, undef);
	slowprint "220 spamd IP-based SPAM blocker";
	while (<STDIN>) {
		s/[\r\n]+$//;
		slowprint "250 spamd Hello, pleased to meet you" if /HELO.*/i;
		slowprint "250 2.0.0: Ok" if /(MAIL FROM:.*)|(RCPT TO:.*)/i;
		alarm($timeout);
		last if /(QUIT)|(^\.$)/i;
	}
	slowprint "221 2.0.0: Bye";
	$elapsed_time = time - $start_time;
	do_log($self->{'server'}->{'peeraddr'}, $elapsed_time);
	alarm($previous_alarm);
}

sub do_log {
	my $ip_addr = shift;
	my $elapsed_time = shift;
	my $msg = shift;

	if ( not defined $elapsed_time ) {
		$elapsed_time = 0;
	}
	my $id = 'spamd.pl';
	my $fac = 'mail';

	$fac =~ /^[A-Za-z0-9_]+\z/
		or die "Suspicious syslog facility name: $fac";
	my $syslog_facility_num = eval("LOG_\U$fac");
	$syslog_facility_num =~ /^\d+\z/
		or die "Unknown syslog facility name: $fac";

	openlog($id, LOG_PID | LOG_NDELAY, $syslog_facility_num);
	if ( $elapsed_time ne 0 ) {
		syslog LOG_INFO, "Spammer %s stuck for %d seconds", $ip_addr, $elapsed_time;
	} elsif ( defined $msg ) {
		syslog LOG_INFO, "Spammer %s %s", $ip_addr, $msg;
	} else {
		syslog LOG_INFO, "Spammer %s connected", $ip_addr;
	}
	closelog();
}

sub do_log_and_die {
	my $ip = shift;
	my $time = shift;
	my $msg = shift;
	do_log($ip, $time, $msg);
	die;
}

# option parsing
getopts('dg:p:t:u:', \%opts);
if ( defined $opts{'d'} ) {
	$daemonize = 1;
	if (defined $opts{'g'} and defined $opts{'u'} ) {
		$user=$opts{'u'};
		$group=$opts{'g'};
	} else {
		die("Daemon mode needs user [-u] and group [-g] parameters");
	}
}

# Set a port different from default
if ( defined $opts{'p'} ) {
	$port = $opts{'p'};
}

# Set a timeout for alarm(3)
if ( defined $opts{'t'} ) {
	$timeout = $opts{'t'};
}

# Daemonize if requested
if ($daemonize eq 1) {
	daemonize(
	$user,
	$group,
	$pid
	);
}
spamd->run(port => $port, ipv => $listenip);
1;
