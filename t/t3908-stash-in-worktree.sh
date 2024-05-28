#!/bin/sh
#
# Copyright (c) 2019 Johannes E Schindelin
#

test_description='Test shit stash in a worktree'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial &&
	shit worktree add wt &&
	test_commit -C wt in-worktree
'

test_expect_success 'apply in subdirectory' '
	mkdir wt/subdir &&
	(
		cd wt/subdir &&
		echo modified >../initial.t &&
		shit stash &&
		shit stash apply >out
	) &&
	grep "\.\.\/initial\.t" wt/subdir/out
'

test_done
