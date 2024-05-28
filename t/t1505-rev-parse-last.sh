#!/bin/sh

test_description='test @{-N} syntax'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh


make_commit () {
	echo "$1" > "$1" &&
	shit add "$1" &&
	shit commit -m "$1"
}


test_expect_success 'setup' '

	make_commit 1 &&
	shit branch side &&
	make_commit 2 &&
	make_commit 3 &&
	shit checkout side &&
	make_commit 4 &&
	shit merge main &&
	shit checkout main

'

# 1 -- 2 -- 3 main
#  \         \
#   \         \
#    --- 4 --- 5 side
#
# and 'side' should be the last branch

test_expect_success '@{-1} works' '
	test_cmp_rev side @{-1}
'

test_expect_success '@{-1}~2 works' '
	test_cmp_rev side~2 @{-1}~2
'

test_expect_success '@{-1}^2 works' '
	test_cmp_rev side^2 @{-1}^2
'

test_expect_success '@{-1}@{1} works' '
	test_cmp_rev side@{1} @{-1}@{1}
'

test_expect_success '@{-2} works' '
	test_cmp_rev main @{-2}
'

test_expect_success '@{-3} fails' '
	test_must_fail shit rev-parse @{-3}
'

test_done


