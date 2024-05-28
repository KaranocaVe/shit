#!/bin/sh

test_description='packed-refs entries are covered by loose refs'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_tick &&
	shit commit --allow-empty -m one &&
	one=$(shit rev-parse HEAD) &&
	shit for-each-ref >actual &&
	echo "$one commit	refs/heads/main" >expect &&
	test_cmp expect actual &&

	shit pack-refs --all &&
	shit for-each-ref >actual &&
	echo "$one commit	refs/heads/main" >expect &&
	test_cmp expect actual &&

	shit checkout --orphan another &&
	test_tick &&
	shit commit --allow-empty -m two &&
	two=$(shit rev-parse HEAD) &&
	shit checkout -B main &&
	shit branch -D another &&

	shit for-each-ref >actual &&
	echo "$two commit	refs/heads/main" >expect &&
	test_cmp expect actual &&

	shit reflog expire --expire=now --all &&
	shit prune &&
	shit tag -m v1.0 v1.0 main
'

test_expect_success 'no error from stale entry in packed-refs' '
	shit describe main >actual 2>&1 &&
	echo "v1.0" >expect &&
	test_cmp expect actual
'

test_done
