#!/bin/sh

test_description='Peter MacMillan'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo Hello >file &&
	shit add file &&
	test_tick &&
	shit commit -m V1 &&
	echo Hello world >file &&
	shit add file &&
	shit checkout -b other
'

test_expect_success 'check all changes are staged' '
	shit diff --exit-code
'

test_expect_success 'second commit' '
	shit commit -m V2
'

test_expect_success 'check' '
	shit diff --cached --exit-code
'

test_done
