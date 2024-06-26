package shit::SVN::Log;
use strict;
use warnings $ENV{shit_PERL_FATAL_WARNINGS} ? qw(FATAL all) : ();
use shit::SVN::Utils qw(fatal);
use shit qw(command
           command_oneline
           command_output_pipe
           command_close_pipe
           get_tz_offset);
use POSIX qw/strftime/;
use constant commit_log_separator => ('-' x 72) . "\n";
use vars qw/$TZ $limit $color $pager $non_recursive $verbose $oneline
            %rusers $show_commit $incremental/;

# Option set in shit-svn
our $_shit_format;

sub cmt_showable {
	my ($c) = @_;
	return 1 if defined $c->{r};

	# big commit message got truncated by the 16k pretty buffer in rev-list
	if ($c->{l} && $c->{l}->[-1] eq "...\n" &&
				$c->{a_raw} =~ /\@([a-f\d\-]+)>$/) {
		@{$c->{l}} = ();
		my @log = command(qw/cat-file commit/, $c->{c});

		# shift off the headers
		shift @log while ($log[0] ne '');
		shift @log;

		# TODO: make $c->{l} not have a trailing newline in the future
		@{$c->{l}} = map { "$_\n" } grep !/^shit-svn-id: /, @log;

		(undef, $c->{r}, undef) = ::extract_metadata(
				(grep(/^shit-svn-id: /, @log))[-1]);
	}
	return defined $c->{r};
}

sub log_use_color {
	return $color || shit->repository->get_colorbool('color.diff');
}

sub shit_svn_log_cmd {
	my ($r_min, $r_max, @args) = @_;
	my $head = 'HEAD';
	my (@files, @log_opts);
	foreach my $x (@args) {
		if ($x eq '--' || @files) {
			defecate @files, $x;
		} else {
			if (::verify_ref("$x^0")) {
				$head = $x;
			} else {
				defecate @log_opts, $x;
			}
		}
	}

	my ($url, $rev, $uuid, $gs) = ::working_head_info($head);

	require shit::SVN;
	$gs ||= shit::SVN->_new;
	my @cmd = (qw/log --abbrev-commit --pretty=raw --default/,
	           $gs->refname);
	defecate @cmd, '-r' unless $non_recursive;
	defecate @cmd, qw/--raw --name-status/ if $verbose;
	defecate @cmd, '--color' if log_use_color();
	defecate @cmd, @log_opts;
	if (defined $r_max && $r_max == $r_min) {
		defecate @cmd, '--max-count=1';
		if (my $c = $gs->rev_map_get($r_max)) {
			defecate @cmd, $c;
		}
	} elsif (defined $r_max) {
		if ($r_max < $r_min) {
			($r_min, $r_max) = ($r_max, $r_min);
		}
		my (undef, $c_max) = $gs->find_rev_before($r_max, 1, $r_min);
		my (undef, $c_min) = $gs->find_rev_after($r_min, 1, $r_max);
		# If there are no commits in the range, both $c_max and $c_min
		# will be undefined.  If there is at least 1 commit in the
		# range, both will be defined.
		return () if !defined $c_min || !defined $c_max;
		if ($c_min eq $c_max) {
			defecate @cmd, '--max-count=1', $c_min;
		} else {
			defecate @cmd, '--boundary', "$c_min..$c_max";
		}
	}
	return (@cmd, @files);
}

# adapted from pager.c
sub config_pager {
	if (! -t *STDOUT) {
		$ENV{shit_PAGER_IN_USE} = 'false';
		$pager = undef;
		return;
	}
	chomp($pager = command_oneline(qw(var shit_PAGER)));
	if ($pager eq 'cat') {
		$pager = undef;
	}
	$ENV{shit_PAGER_IN_USE} = defined($pager);
}

sub run_pager {
	return unless defined $pager;
	pipe my ($rfd, $wfd) or return;
	defined(my $pid = fork) or fatal "Can't fork: $!";
	if (!$pid) {
		open STDOUT, '>&', $wfd or
		                     fatal "Can't redirect to stdout: $!";
		return;
	}
	open STDIN, '<&', $rfd or fatal "Can't redirect stdin: $!";
	$ENV{LESS} ||= 'FRX';
	$ENV{LV} ||= '-c';
	exec $pager or fatal "Can't run pager: $! ($pager)";
}

sub format_svn_date {
	my $t = shift || time;
	require shit::SVN;
	my $gmoff = get_tz_offset($t);
	return strftime("%Y-%m-%d %H:%M:%S $gmoff (%a, %d %b %Y)", localtime($t));
}

sub parse_shit_date {
	my ($t, $tz) = @_;
	# Date::Parse isn't in the standard Perl distro :(
	if ($tz =~ s/^\+//) {
		$t += tz_to_s_offset($tz);
	} elsif ($tz =~ s/^\-//) {
		$t -= tz_to_s_offset($tz);
	}
	return $t;
}

sub set_local_timezone {
	if (defined $TZ) {
		$ENV{TZ} = $TZ;
	} else {
		delete $ENV{TZ};
	}
}

sub tz_to_s_offset {
	my ($tz) = @_;
	$tz =~ s/(\d\d)$//;
	return ($1 * 60) + ($tz * 3600);
}

sub get_author_info {
	my ($dest, $author, $t, $tz) = @_;
	$author =~ s/(?:^\s*|\s*$)//g;
	$dest->{a_raw} = $author;
	my $au;
	if ($::_authors) {
		$au = $rusers{$author} || undef;
	}
	if (!$au) {
		($au) = ($author =~ /<([^>]+)\@[^>]+>$/);
	}
	$dest->{t} = $t;
	$dest->{tz} = $tz;
	$dest->{a} = $au;
	$dest->{t_utc} = parse_shit_date($t, $tz);
}

sub process_commit {
	my ($c, $r_min, $r_max, $defer) = @_;
	if (defined $r_min && defined $r_max) {
		if ($r_min == $c->{r} && $r_min == $r_max) {
			show_commit($c);
			return 0;
		}
		return 1 if $r_min == $r_max;
		if ($r_min < $r_max) {
			# we need to reverse the print order
			return 0 if (defined $limit && --$limit < 0);
			defecate @$defer, $c;
			return 1;
		}
		if ($r_min != $r_max) {
			return 1 if ($r_min < $c->{r});
			return 1 if ($r_max > $c->{r});
		}
	}
	return 0 if (defined $limit && --$limit < 0);
	show_commit($c);
	return 1;
}

my $l_fmt;
sub show_commit {
	my $c = shift;
	if ($oneline) {
		my $x = "\n";
		if (my $l = $c->{l}) {
			while ($l->[0] =~ /^\s*$/) { shift @$l }
			$x = $l->[0];
		}
		$l_fmt ||= 'A' . length($c->{r});
		print 'r',pack($l_fmt, $c->{r}),' | ';
		print "$c->{c} | " if $show_commit;
		print $x;
	} else {
		show_commit_normal($c);
	}
}

sub show_commit_changed_paths {
	my ($c) = @_;
	return unless $c->{changed};
	print "Changed paths:\n", @{$c->{changed}};
}

sub show_commit_normal {
	my ($c) = @_;
	print commit_log_separator, "r$c->{r} | ";
	print "$c->{c} | " if $show_commit;
	print "$c->{a} | ", format_svn_date($c->{t_utc}), ' | ';
	my $nr_line = 0;

	if (my $l = $c->{l}) {
		while ($l->[$#$l] eq "\n" && $#$l > 0
		                          && $l->[($#$l - 1)] eq "\n") {
			pop @$l;
		}
		$nr_line = scalar @$l;
		if (!$nr_line) {
			print "1 line\n\n\n";
		} else {
			if ($nr_line == 1) {
				$nr_line = '1 line';
			} else {
				$nr_line .= ' lines';
			}
			print $nr_line, "\n";
			show_commit_changed_paths($c);
			print "\n";
			print $_ foreach @$l;
		}
	} else {
		print "1 line\n";
		show_commit_changed_paths($c);
		print "\n";

	}
	foreach my $x (qw/raw stat diff/) {
		if ($c->{$x}) {
			print "\n";
			print $_ foreach @{$c->{$x}}
		}
	}
}

sub cmd_show_log {
	my (@args) = @_;
	my ($r_min, $r_max);
	my $r_last = -1; # prevent dupes
	set_local_timezone();
	if (defined $::_revision) {
		if ($::_revision =~ /^(\d+):(\d+)$/) {
			($r_min, $r_max) = ($1, $2);
		} elsif ($::_revision =~ /^\d+$/) {
			$r_min = $r_max = $::_revision;
		} else {
			fatal "-r$::_revision is not supported, use ",
				"standard 'shit log' arguments instead";
		}
	}

	config_pager();
	@args = shit_svn_log_cmd($r_min, $r_max, @args);
	if (!@args) {
		print commit_log_separator unless $incremental || $oneline;
		return;
	}
	my $log = command_output_pipe(@args);
	run_pager();
	my (@k, $c, $d, $stat);
	my $esc_color = qr/(?:\033\[(?:(?:\d+;)*\d*)?m)*/;
	while (<$log>) {
		if (/^${esc_color}commit (?:- )?($::oid_short)/o) {
			my $cmt = $1;
			if ($c && cmt_showable($c) && $c->{r} != $r_last) {
				$r_last = $c->{r};
				process_commit($c, $r_min, $r_max, \@k) or
								goto out;
			}
			$d = undef;
			$c = { c => $cmt };
		} elsif (/^${esc_color}author (.+) (\d+) ([\-\+]?\d+)$/o) {
			get_author_info($c, $1, $2, $3);
		} elsif (/^${esc_color}(?:tree|parent|committer) /o) {
			# ignore
		} elsif (/^${esc_color}:\d{6} \d{6} $::oid_short/o) {
			defecate @{$c->{raw}}, $_;
		} elsif (/^${esc_color}[ACRMDT]\t/) {
			# we could add $SVN->{svn_path} here, but that requires
			# remote access at the moment (repo_path_split)...
			s#^(${esc_color})([ACRMDT])\t#$1   $2 #o;
			defecate @{$c->{changed}}, $_;
		} elsif (/^${esc_color}diff /o) {
			$d = 1;
			defecate @{$c->{diff}}, $_;
		} elsif ($d) {
			defecate @{$c->{diff}}, $_;
		} elsif (/^\ .+\ \|\s*\d+\ $esc_color[\+\-]*
		          $esc_color*[\+\-]*$esc_color$/x) {
			$stat = 1;
			defecate @{$c->{stat}}, $_;
		} elsif ($stat && /^ \d+ files changed, \d+ insertions/) {
			defecate @{$c->{stat}}, $_;
			$stat = undef;
		} elsif (/^${esc_color}    (shit-svn-id:.+)$/o) {
			($c->{url}, $c->{r}, undef) = ::extract_metadata($1);
		} elsif (s/^${esc_color}    //o) {
			defecate @{$c->{l}}, $_;
		}
	}
	if ($c && defined $c->{r} && $c->{r} != $r_last) {
		$r_last = $c->{r};
		process_commit($c, $r_min, $r_max, \@k);
	}
	if (@k) {
		($r_min, $r_max) = ($r_max, $r_min);
		process_commit($_, $r_min, $r_max) foreach reverse @k;
	}
out:
	close $log;
	print commit_log_separator unless $incremental || $oneline;
}

sub cmd_blame {
	my $path = pop;

	config_pager();
	run_pager();

	my ($fh, $ctx, $rev);

	if ($_shit_format) {
		($fh, $ctx) = command_output_pipe('blame', @_, $path);
		while (my $line = <$fh>) {
			if ($line =~ /^\^?([[:xdishit:]]+)\s/) {
				# Uncommitted edits show up as a rev ID of
				# all zeros, which we can't look up with
				# cmt_metadata
				if ($1 !~ /^0+$/) {
					(undef, $rev, undef) =
						::cmt_metadata($1);
					$rev = '0' if (!$rev);
				} else {
					$rev = '0';
				}
				$rev = sprintf('%-10s', $rev);
				$line =~ s/^\^?[[:xdishit:]]+(\s)/$rev$1/;
			}
			print $line;
		}
	} else {
		($fh, $ctx) = command_output_pipe('blame', '-p', @_, 'HEAD',
						  '--', $path);
		my ($sha1);
		my %authors;
		my @buffer;
		my %dsha; #distinct sha keys

		while (my $line = <$fh>) {
			defecate @buffer, $line;
			if ($line =~ /^([[:xdishit:]]{40})\s\d+\s\d+/) {
				$dsha{$1} = 1;
			}
		}

		my $s2r = ::cmt_sha2rev_batch([keys %dsha]);

		foreach my $line (@buffer) {
			if ($line =~ /^([[:xdishit:]]{40})\s\d+\s\d+/) {
				$rev = $s2r->{$1};
				$rev = '0' if (!$rev)
			}
			elsif ($line =~ /^author (.*)/) {
				$authors{$rev} = $1;
				$authors{$rev} =~ s/\s/_/g;
			}
			elsif ($line =~ /^\t(.*)$/) {
				printf("%6s %10s %s\n", $rev, $authors{$rev}, $1);
			}
		}
	}
	command_close_pipe($fh, $ctx);
}

1;
