#!/bin/sh

test_description='checkout switching away from an invalid branch'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo hello >world &&
	shit add world &&
	shit commit -m initial
'

test_expect_success 'checkout should not start branch from a tree' '
	test_must_fail shit checkout -b newbranch main^{tree}
'

test_expect_success REFFILES 'checkout main from invalid HEAD' '
	echo $ZERO_OID >.shit/HEAD &&
	shit checkout main --
'

test_expect_success REFFILES 'checkout notices failure to lock HEAD' '
	test_when_finished "rm -f .shit/HEAD.lock" &&
	>.shit/HEAD.lock &&
	test_must_fail shit checkout -b other
'

test_expect_success 'create ref directory/file conflict scenario' '
	shit update-ref refs/heads/outer/inner main &&
	reset_to_df () {
		shit symbolic-ref HEAD refs/heads/outer
	}
'

test_expect_success 'checkout away from d/f HEAD (unpacked, to branch)' '
	reset_to_df &&
	shit checkout main
'

test_expect_success 'checkout away from d/f HEAD (unpacked, to detached)' '
	reset_to_df &&
	shit checkout --detach main
'

test_expect_success 'pack refs' '
	shit pack-refs --all --prune
'

test_expect_success 'checkout away from d/f HEAD (packed, to branch)' '
	reset_to_df &&
	shit checkout main
'

test_expect_success 'checkout away from d/f HEAD (packed, to detached)' '
	reset_to_df &&
	shit checkout --detach main
'
test_done
