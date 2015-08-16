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
}

sub process_request {
	my $self = shift;
	slowprint "220 spamd IP-based SPAM blocker\015\012";
	while (<STDIN>) {
		s/[\r\n]+$//;
		# slowprint "You said '$_'\015\012"; # basic echo
		last if /quit/i;
	}
	slowprint "221 2.0.0: Bye\015\012";
}

spamd->run(port => 2525, ipv => '*');
