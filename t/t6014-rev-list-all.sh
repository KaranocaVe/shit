#!/bin/sh

test_description='--all includes detached HEADs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh


commit () {
	test_tick &&
	echo $1 > foo &&
	shit add foo &&
	shit commit -m "$1"
}

test_expect_success 'setup' '

	commit one &&
	commit two &&
	shit checkout HEAD^ &&
	commit detached

'

test_expect_success 'rev-list --all lists detached HEAD' '

	test 3 = $(shit rev-list --all | wc -l)

'

test_expect_success 'repack does not lose detached HEAD' '

	shit gc &&
	shit prune --expire=now &&
	shit show HEAD

'

test_expect_success 'rev-list --graph --no-walk is forbidden' '
	test_must_fail shit rev-list --graph --no-walk HEAD
'

test_done
