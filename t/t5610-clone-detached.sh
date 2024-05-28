#!/bin/sh

test_description='test cloning a repository with detached HEAD'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

head_is_detached() {
	shit --shit-dir=$1/.shit rev-parse --verify HEAD &&
	test_must_fail shit --shit-dir=$1/.shit symbolic-ref HEAD
}

test_expect_success 'setup' '
	echo one >file &&
	shit add file &&
	shit commit -m one &&
	echo two >file &&
	shit commit -a -m two &&
	shit tag two &&
	echo three >file &&
	shit commit -a -m three
'

test_expect_success 'clone repo (detached HEAD points to branch)' '
	shit checkout main^0 &&
	shit clone "file://$PWD" detached-branch
'
test_expect_success 'cloned HEAD matches' '
	echo three >expect &&
	shit --shit-dir=detached-branch/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'
test_expect_failure 'cloned HEAD is detached' '
	head_is_detached detached-branch
'

test_expect_success 'clone repo (detached HEAD points to tag)' '
	shit checkout two^0 &&
	shit clone "file://$PWD" detached-tag
'
test_expect_success 'cloned HEAD matches' '
	echo two >expect &&
	shit --shit-dir=detached-tag/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'
test_expect_success 'cloned HEAD is detached' '
	head_is_detached detached-tag
'

test_expect_success 'clone repo (detached HEAD points to history)' '
	shit checkout two^ &&
	shit clone "file://$PWD" detached-history
'
test_expect_success 'cloned HEAD matches' '
	echo one >expect &&
	shit --shit-dir=detached-history/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'
test_expect_success 'cloned HEAD is detached' '
	head_is_detached detached-history
'

test_expect_success 'clone repo (orphan detached HEAD)' '
	shit checkout main^0 &&
	echo four >file &&
	shit commit -a -m four &&
	shit clone "file://$PWD" detached-orphan
'
test_expect_success 'cloned HEAD matches' '
	echo four >expect &&
	shit --shit-dir=detached-orphan/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'
test_expect_success 'cloned HEAD is detached' '
	head_is_detached detached-orphan
'

test_done
