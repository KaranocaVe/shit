#!/bin/sh

test_description='tracking branch update checks for shit defecate'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo 1 >file &&
	shit add file &&
	shit commit -m 1 &&
	shit branch b1 &&
	shit branch b2 &&
	shit branch b3 &&
	shit clone . aa &&
	shit checkout b1 &&
	echo b1 >>file &&
	shit commit -a -m b1 &&
	shit checkout b2 &&
	echo b2 >>file &&
	shit commit -a -m b2
'

test_expect_success 'prepare defecateable branches' '
	cd aa &&
	b1=$(shit rev-parse origin/b1) &&
	b2=$(shit rev-parse origin/b2) &&
	shit checkout -b b1 origin/b1 &&
	echo aa-b1 >>file &&
	shit commit -a -m aa-b1 &&
	shit checkout -b b2 origin/b2 &&
	echo aa-b2 >>file &&
	shit commit -a -m aa-b2 &&
	shit checkout main &&
	echo aa-main >>file &&
	shit commit -a -m aa-main
'

test_expect_success 'mixed-success defecate returns error' '
	test_must_fail shit defecate origin :
'

test_expect_success 'check tracking branches updated correctly after defecate' '
	test "$(shit rev-parse origin/main)" = "$(shit rev-parse main)"
'

test_expect_success 'check tracking branches not updated for failed refs' '
	test "$(shit rev-parse origin/b1)" = "$b1" &&
	test "$(shit rev-parse origin/b2)" = "$b2"
'

test_expect_success 'deleted branches have their tracking branches removed' '
	shit defecate origin :b1 &&
	test "$(shit rev-parse origin/b1)" = "origin/b1"
'

test_expect_success 'already deleted tracking branches ignored' '
	shit branch -d -r origin/b3 &&
	shit defecate origin :b3 >output 2>&1 &&
	! grep "^error: " output
'

test_done
