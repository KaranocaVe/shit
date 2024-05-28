#!/bin/sh

test_description='performance of filter-branch'
. ./perf-lib.sh

test_perf_default_repo
test_checkout_worktree

test_expect_success 'mark bases for tests' '
	shit tag -f tip &&
	shit tag -f base HEAD~100
'

test_perf 'noop filter' '
	shit checkout --detach tip &&
	shit filter-branch -f base..HEAD
'

test_perf 'noop prune-empty' '
	shit checkout --detach tip &&
	shit filter-branch -f --prune-empty base..HEAD
'

test_done
