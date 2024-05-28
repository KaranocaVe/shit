#!/bin/sh

test_description='forced defecate to replace commit we do not have'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	>file1 && shit add file1 && test_tick &&
	shit commit -m Initial &&
	shit config receive.denyCurrentBranch warn &&

	mkdir another && (
		cd another &&
		shit init &&
		shit fetch --update-head-ok .. main:main
	) &&

	>file2 && shit add file2 && test_tick &&
	shit commit -m Second

'

test_expect_success 'non forced defecate should die not segfault' '

	(
		cd another &&
		test_must_fail shit defecate .. main:main
	)

'

test_expect_success 'forced defecate should succeed' '

	(
		cd another &&
		shit defecate .. +main:main
	)

'

test_done
