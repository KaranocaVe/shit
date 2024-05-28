#!/bin/sh
#
# Copyright (c) 2006 Josh England
#

test_description='Test the post-merge hook.'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo Data for commit0. >a &&
	shit update-index --add a &&
	tree0=$(shit write-tree) &&
	commit0=$(echo setup | shit commit-tree $tree0) &&
	echo Changed data for commit1. >a &&
	shit update-index a &&
	tree1=$(shit write-tree) &&
	commit1=$(echo modify | shit commit-tree $tree1 -p $commit0) &&
	shit update-ref refs/heads/main $commit0 &&
	shit clone ./. clone1 &&
	shit_DIR=clone1/.shit shit update-index --add a &&
	shit clone ./. clone2 &&
	shit_DIR=clone2/.shit shit update-index --add a
'

test_expect_success 'setup clone hooks' '
	test_when_finished "rm -f hook" &&
	cat >hook <<-\EOF &&
	echo $@ >>$shit_DIR/post-merge.args
	EOF

	test_hook --setup -C clone1 post-merge <hook &&
	test_hook --setup -C clone2 post-merge <hook
'

test_expect_success 'post-merge does not run for up-to-date ' '
	shit_DIR=clone1/.shit shit merge $commit0 &&
	! test -f clone1/.shit/post-merge.args
'

test_expect_success 'post-merge runs as expected ' '
	shit_DIR=clone1/.shit shit merge $commit1 &&
	test -e clone1/.shit/post-merge.args
'

test_expect_success 'post-merge from normal merge receives the right argument ' '
	grep 0 clone1/.shit/post-merge.args
'

test_expect_success 'post-merge from squash merge runs as expected ' '
	shit_DIR=clone2/.shit shit merge --squash $commit1 &&
	test -e clone2/.shit/post-merge.args
'

test_expect_success 'post-merge from squash merge receives the right argument ' '
	grep 1 clone2/.shit/post-merge.args
'

test_done
