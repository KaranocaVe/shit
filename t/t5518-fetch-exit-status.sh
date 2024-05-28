#!/bin/sh
#
# Copyright (c) 2008 Dmitry V. Levin
#

test_description='fetch exit status test'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	>file &&
	shit add file &&
	shit commit -m initial &&

	shit checkout -b side &&
	echo side >file &&
	shit commit -a -m side &&

	shit checkout main &&
	echo next >file &&
	shit commit -a -m next
'

test_expect_success 'non-fast-forward fetch' '

	test_must_fail shit fetch . main:side

'

test_expect_success 'forced update' '

	shit fetch . +main:side

'

test_done
