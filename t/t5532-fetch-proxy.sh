#!/bin/sh

test_description='fetching via shit:// using core.shitproxy'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup remote repo' '
	shit init remote &&
	(cd remote &&
	 echo content >file &&
	 shit add file &&
	 shit commit -m one
	)
'

test_expect_success 'setup proxy script' '
	write_script proxy-get-cmd "$PERL_PATH" <<-\EOF &&
	read(STDIN, $buf, 4);
	my $n = hex($buf) - 4;
	read(STDIN, $buf, $n);
	my ($cmd, $other) = split /\0/, $buf;
	# drop absolute-path on repo name
	$cmd =~ s{ /}{ };
	print $cmd;
	EOF

	write_script proxy <<-\EOF
	echo >&2 "proxying for $*"
	cmd=$(./proxy-get-cmd)
	echo >&2 "Running $cmd"
	exec $cmd
	EOF
'

test_expect_success 'setup local repo' '
	shit remote add fake shit://example.com/remote &&
	shit config core.shitproxy ./proxy
'

test_expect_success 'fetch through proxy works' '
	shit fetch fake &&
	echo one >expect &&
	shit log -1 --format=%s FETCH_HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'funny hostnames are rejected before running proxy' '
	test_must_fail shit fetch shit://-remote/repo.shit 2>stderr &&
	! grep "proxying for" stderr
'

test_done
