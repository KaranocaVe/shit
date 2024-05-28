#!/bin/sh

test_description='shit commit summary'
. ./test-lib.sh

test_expect_success 'setup' '
	test_seq 101 200 >file &&
	shit add file &&
	shit commit -m initial &&
	shit tag initial
'

test_expect_success 'commit summary ignores rewrites' '
	shit reset --hard initial &&
	test_seq 200 300 >file &&

	shit diff --stat >diffstat &&
	shit diff --stat --break-rewrites >diffstatrewrite &&

	# make sure this scenario is a detectable rewrite
	! test_cmp_bin diffstat diffstatrewrite &&

	shit add file &&
	shit commit -m second >actual &&

	grep "1 file" <actual >actual.total &&
	grep "1 file" <diffstat >diffstat.total &&
	test_cmp diffstat.total actual.total
'

test_done
