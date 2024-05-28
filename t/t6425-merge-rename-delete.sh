#!/bin/sh

test_description='Merge-recursive rename/delete conflict message'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'rename/delete' '
	echo foo >A &&
	shit add A &&
	shit commit -m "initial" &&

	shit checkout -b rename &&
	shit mv A B &&
	shit commit -m "rename" &&

	shit checkout main &&
	shit rm A &&
	shit commit -m "delete" &&

	test_must_fail shit merge --strategy=recursive rename >output &&
	test_grep "CONFLICT (rename/delete): A.* renamed .*to B.* in rename" output &&
	test_grep "CONFLICT (rename/delete): A.*deleted in HEAD." output
'

test_done
