#!/usr/bin/perl -w
package spamd;

use base qw(Net::Server);

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

sub process_request {
	my $self = shift;
	slowprint "220 spamd IP-based SPAM blocker";
	while (<STDIN>) {
		s/[\r\n]+$//;
		slowprint "250 spamd Hello, pleased to meet you" if /HELO.*/i;
		slowprint "250 2.0.0: Ok" if /(MAIL FROM:.*)|(RCPT TO:.*)/i;
		last if /(QUIT)(\.)/i;
	}
	slowprint "221 2.0.0: Bye";
}

spamd->run(port => 2525, ipv => '*');
