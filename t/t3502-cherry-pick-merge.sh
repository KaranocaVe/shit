#!/bin/sh

test_description='cherry picking and reverting a merge

		b---c
	       /   /
	initial---a

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	>A &&
	>B &&
	shit add A B &&
	shit commit -m "Initial" &&
	shit tag initial &&
	shit branch side &&
	echo new line >A &&
	shit commit -m "add line to A" A &&
	shit tag a &&
	shit checkout side &&
	echo new line >B &&
	shit commit -m "add line to B" B &&
	shit tag b &&
	shit checkout main &&
	shit merge side &&
	shit tag c

'

test_expect_success 'cherry-pick -m complains of bogus numbers' '
	# expect 129 here to distinguish between cases where
	# there was nothing to cherry-pick
	test_expect_code 129 shit cherry-pick -m &&
	test_expect_code 129 shit cherry-pick -m foo b &&
	test_expect_code 129 shit cherry-pick -m -1 b &&
	test_expect_code 129 shit cherry-pick -m 0 b
'

test_expect_success 'cherry-pick explicit first parent of a non-merge' '

	shit reset --hard &&
	shit checkout a^0 &&
	shit cherry-pick -m 1 b &&
	shit diff --exit-code c --

'

test_expect_success 'cherry pick a merge without -m should fail' '

	shit reset --hard &&
	shit checkout a^0 &&
	test_must_fail shit cherry-pick c &&
	shit diff --exit-code a --

'

test_expect_success 'cherry pick a merge (1)' '

	shit reset --hard &&
	shit checkout a^0 &&
	shit cherry-pick -m 1 c &&
	shit diff --exit-code c

'

test_expect_success 'cherry pick a merge (2)' '

	shit reset --hard &&
	shit checkout b^0 &&
	shit cherry-pick -m 2 c &&
	shit diff --exit-code c

'

test_expect_success 'cherry pick a merge relative to nonexistent parent should fail' '

	shit reset --hard &&
	shit checkout b^0 &&
	test_must_fail shit cherry-pick -m 3 c

'

test_expect_success 'revert explicit first parent of a non-merge' '

	shit reset --hard &&
	shit checkout c^0 &&
	shit revert -m 1 b &&
	shit diff --exit-code a --

'

test_expect_success 'revert a merge without -m should fail' '

	shit reset --hard &&
	shit checkout c^0 &&
	test_must_fail shit revert c &&
	shit diff --exit-code c

'

test_expect_success 'revert a merge (1)' '

	shit reset --hard &&
	shit checkout c^0 &&
	shit revert -m 1 c &&
	shit diff --exit-code a --

'

test_expect_success 'revert a merge (2)' '

	shit reset --hard &&
	shit checkout c^0 &&
	shit revert -m 2 c &&
	shit diff --exit-code b --

'

test_expect_success 'revert a merge relative to nonexistent parent should fail' '

	shit reset --hard &&
	shit checkout c^0 &&
	test_must_fail shit revert -m 3 c &&
	shit diff --exit-code c

'

test_done
