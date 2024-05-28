#!/bin/sh

test_description='checkout from unborn branch'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir parent &&
	(
		cd parent &&
		shit init &&
		echo content >file &&
		shit add file &&
		shit commit -m base
	) &&
	shit fetch parent main:origin
'

test_expect_success 'checkout from unborn preserves untracked files' '
	echo precious >expect &&
	echo precious >file &&
	test_must_fail shit checkout -b new origin &&
	test_cmp expect file
'

test_expect_success 'checkout from unborn preserves index contents' '
	echo precious >expect &&
	echo precious >file &&
	shit add file &&
	test_must_fail shit checkout -b new origin &&
	test_cmp expect file &&
	shit show :file >file &&
	test_cmp expect file
'

test_expect_success 'checkout from unborn merges identical index contents' '
	echo content >file &&
	shit add file &&
	shit checkout -b new origin
'

test_expect_success 'checking out another branch from unborn state' '
	shit checkout --orphan newroot &&
	shit checkout -b anothername &&
	test_must_fail shit show-ref --verify refs/heads/newroot &&
	shit symbolic-ref HEAD >actual &&
	echo refs/heads/anothername >expect &&
	test_cmp expect actual
'

test_expect_success 'checking out in a newly created repo' '
	test_create_repo empty &&
	(
		cd empty &&
		shit symbolic-ref HEAD >expect &&
		test_must_fail shit checkout &&
		shit symbolic-ref HEAD >actual &&
		test_cmp expect actual
	)
'

test_done
