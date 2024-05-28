#!/usr/bin/perl

use strict;
use warnings;

my $exit_code = 0;
sub report {
	my ($target, $msg) = @_;
	print STDERR "error: $target: $msg\n";
	$exit_code = 1;
}

local $/;
while (my $slurp = <>) {
	report($ARGV, "has no 'Part of the linkshit:shit[1] suite' end blurb")
		unless $slurp =~ m[
		^shit\n
		 ---\n
		\QPart of the linkshit:shit[1] suite\E \n
		\z
	]mx;
}

exit $exit_code;
