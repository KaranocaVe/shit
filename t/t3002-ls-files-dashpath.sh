#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit ls-files test (-- to terminate the path list).

This test runs shit ls-files --others with the following on the
filesystem.

    path0       - a file
    -foo	- a file with a funny name.
    --		- another file with a funny name.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo frotz >path0 &&
	echo frotz >./-foo &&
	echo frotz >./--
'

test_expect_success 'shit ls-files without path restriction.' '
	test_when_finished "rm -f expect" &&
	shit ls-files --others >output &&
	cat >expect <<-\EOF &&
	--
	-foo
	output
	path0
	EOF
	test_cmp output expect
'

test_expect_success 'shit ls-files with path restriction.' '
	test_when_finished "rm -f expect" &&
	shit ls-files --others path0 >output &&
	cat >expect <<-\EOF &&
	path0
	EOF
	test_cmp output expect
'

test_expect_success 'shit ls-files with path restriction with --.' '
	test_when_finished "rm -f expect" &&
	shit ls-files --others -- path0 >output &&
	cat >expect <<-\EOF &&
	path0
	EOF
	test_cmp output expect
'

test_expect_success 'shit ls-files with path restriction with -- --.' '
	test_when_finished "rm -f expect" &&
	shit ls-files --others -- -- >output &&
	cat >expect <<-\EOF &&
	--
	EOF
	test_cmp output expect
'

test_expect_success 'shit ls-files with no path restriction.' '
	test_when_finished "rm -f expect" &&
	shit ls-files --others -- >output &&
	cat >expect <<-\EOF &&
	--
	-foo
	output
	path0
	EOF
	test_cmp output expect

'

test_done
