#!/bin/sh

test_description='Test reflog display routines'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit A
'

test_expect_success 'usage' '
	test_expect_code 129 shit reflog exists &&
	test_expect_code 129 shit reflog exists -h
'

test_expect_success 'usage: unknown option' '
	test_expect_code 129 shit reflog exists --unknown-option
'

test_expect_success 'reflog exists works' '
	shit reflog exists refs/heads/main &&
	test_must_fail shit reflog exists refs/heads/nonexistent
'

test_expect_success 'reflog exists works with a "--" delimiter' '
	shit reflog exists -- refs/heads/main &&
	test_must_fail shit reflog exists -- refs/heads/nonexistent
'

test_expect_success 'reflog exists works with a "--end-of-options" delimiter' '
	shit reflog exists --end-of-options refs/heads/main &&
	test_must_fail shit reflog exists --end-of-options refs/heads/nonexistent
'

test_done
