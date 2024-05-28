#!/bin/sh

test_description='--reverse combines with --parents'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh


commit () {
	test_tick &&
	echo $1 > foo &&
	shit add foo &&
	shit commit -m "$1"
}

test_expect_success 'set up --reverse example' '
	commit one &&
	shit tag root &&
	commit two &&
	shit checkout -b side HEAD^ &&
	commit three &&
	shit checkout main &&
	shit merge -s ours side &&
	commit five
	'

test_expect_success '--reverse --parents --full-history combines correctly' '
	shit rev-list --parents --full-history main -- foo |
		perl -e "print reverse <>" > expected &&
	shit rev-list --reverse --parents --full-history main -- foo \
		> actual &&
	test_cmp expected actual
	'

test_expect_success '--boundary does too' '
	shit rev-list --boundary --parents --full-history main ^root -- foo |
		perl -e "print reverse <>" > expected &&
	shit rev-list --boundary --reverse --parents --full-history \
		main ^root -- foo > actual &&
	test_cmp expected actual
	'

test_done
