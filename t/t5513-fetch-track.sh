#!/bin/sh

test_description='fetch follows remote-tracking branches correctly'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	>file &&
	shit add . &&
	test_tick &&
	shit commit -m Initial &&
	shit branch b-0 &&
	shit branch b1 &&
	shit branch b/one &&
	test_create_repo other &&
	(
		cd other &&
		shit config remote.origin.url .. &&
		shit config remote.origin.fetch "+refs/heads/b/*:refs/remotes/b/*"
	)
'

test_expect_success fetch '
	(
		cd other && shit fetch origin &&
		test "$(shit for-each-ref --format="%(refname)")" = refs/remotes/b/one
	)
'

test_done
