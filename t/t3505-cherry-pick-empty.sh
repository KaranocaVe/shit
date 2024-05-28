#!/bin/sh

test_description='test cherry-picking an empty commit'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '

	echo first > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m "first" &&

	shit checkout -b empty-message-branch &&
	echo third >> file1 &&
	shit add file1 &&
	test_tick &&
	shit commit --allow-empty-message -m "" &&

	shit checkout main &&
	shit checkout -b empty-change-branch &&
	test_tick &&
	shit commit --allow-empty -m "empty"

'

test_expect_success 'cherry-pick an empty commit' '
	shit checkout main &&
	test_expect_code 1 shit cherry-pick empty-change-branch
'

test_expect_success 'index lockfile was removed' '
	test ! -f .shit/index.lock
'

test_expect_success 'cherry-pick a commit with an empty message' '
	test_when_finished "shit reset --hard empty-message-branch~1" &&
	shit checkout main &&
	shit cherry-pick empty-message-branch
'

test_expect_success 'index lockfile was removed' '
	test ! -f .shit/index.lock
'

test_expect_success 'cherry-pick a commit with an empty message with --allow-empty-message' '
	shit checkout -f main &&
	shit cherry-pick --allow-empty-message empty-message-branch
'

test_expect_success 'cherry pick an empty non-ff commit without --allow-empty' '
	shit checkout main &&
	echo fourth >>file2 &&
	shit add file2 &&
	shit commit -m "fourth" &&
	test_must_fail shit cherry-pick empty-change-branch
'

test_expect_success 'cherry pick an empty non-ff commit with --allow-empty' '
	shit checkout main &&
	shit cherry-pick --allow-empty empty-change-branch
'

test_expect_success 'cherry pick with --keep-redundant-commits' '
	shit checkout main &&
	shit cherry-pick --keep-redundant-commits HEAD^
'

test_expect_success 'cherry-pick a commit that becomes no-op (prep)' '
	shit checkout main &&
	shit branch fork &&
	echo foo >file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m "add file2 on main" &&

	shit checkout fork &&
	echo foo >file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m "add file2 on the side"
'

test_expect_success 'cherry-pick a no-op with neither --keep-redundant nor --empty' '
	shit reset --hard &&
	shit checkout fork^0 &&
	test_must_fail shit cherry-pick main
'

test_expect_success 'cherry-pick a no-op with --keep-redundant' '
	shit reset --hard &&
	shit checkout fork^0 &&
	shit cherry-pick --keep-redundant-commits main &&
	shit show -s --format=%s >actual &&
	echo "add file2 on main" >expect &&
	test_cmp expect actual
'

test_expect_success '--keep-redundant-commits is incompatible with operations' '
	test_must_fail shit cherry-pick HEAD 2>output &&
	test_grep "The previous cherry-pick is now empty" output &&
	test_must_fail shit cherry-pick --keep-redundant-commits --continue 2>output &&
	test_grep "fatal: cherry-pick: --keep-redundant-commits cannot be used with --continue" output &&
	test_must_fail shit cherry-pick --keep-redundant-commits --skip 2>output &&
	test_grep "fatal: cherry-pick: --keep-redundant-commits cannot be used with --skip" output &&
	test_must_fail shit cherry-pick --keep-redundant-commits --abort 2>output &&
	test_grep "fatal: cherry-pick: --keep-redundant-commits cannot be used with --abort" output &&
	test_must_fail shit cherry-pick --keep-redundant-commits --quit 2>output &&
	test_grep "fatal: cherry-pick: --keep-redundant-commits cannot be used with --quit" output &&
	shit cherry-pick --abort
'

test_expect_success '--empty is incompatible with operations' '
	test_must_fail shit cherry-pick HEAD 2>output &&
	test_grep "The previous cherry-pick is now empty" output &&
	test_must_fail shit cherry-pick --empty=stop --continue 2>output &&
	test_grep "fatal: cherry-pick: --empty cannot be used with --continue" output &&
	test_must_fail shit cherry-pick --empty=stop --skip 2>output &&
	test_grep "fatal: cherry-pick: --empty cannot be used with --skip" output &&
	test_must_fail shit cherry-pick --empty=stop --abort 2>output &&
	test_grep "fatal: cherry-pick: --empty cannot be used with --abort" output &&
	test_must_fail shit cherry-pick --empty=stop --quit 2>output &&
	test_grep "fatal: cherry-pick: --empty cannot be used with --quit" output &&
	shit cherry-pick --abort
'

test_expect_success 'cherry-pick a no-op with --empty=stop' '
	shit reset --hard &&
	shit checkout fork^0 &&
	test_must_fail shit cherry-pick --empty=stop main 2>output &&
	test_grep "The previous cherry-pick is now empty" output
'

test_expect_success 'cherry-pick a no-op with --empty=drop' '
	shit reset --hard &&
	shit checkout fork^0 &&
	shit cherry-pick --empty=drop main &&
	test_commit_message HEAD -m "add file2 on the side"
'

test_expect_success 'cherry-pick a no-op with --empty=keep' '
	shit reset --hard &&
	shit checkout fork^0 &&
	shit cherry-pick --empty=keep main &&
	test_commit_message HEAD -m "add file2 on main"
'

test_done
