#!/bin/sh

test_description='performance of reset'
. ./perf-lib.sh

test_perf_default_repo
test_checkout_worktree

test_perf 'reset --hard with change in tree' '
	base=$(shit rev-parse HEAD) &&
	test_commit --no-tag A &&
	new=$(shit rev-parse HEAD) &&

	for i in $(test_seq 10)
	do
		shit reset --hard $new &&
		shit reset --hard $base || return $?
	done
'

test_done
