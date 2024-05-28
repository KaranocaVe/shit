#!/bin/sh

test_description='test aborting in-progress merges

Set up repo with conflicting and non-conflicting branches:

There are three files foo/bar/baz, and the following graph illustrates the
content of these files in each commit:

# foo/bar/baz --- foo/bar/bazz     <-- main
#             \
#              --- foo/barf/bazf   <-- conflict_branch
#               \
#                --- foo/bart/baz  <-- clean_branch

Next, test shit merge --abort with the following variables:
- before/after successful merge (should fail when not in merge context)
- with/without conflicts
- clean/dirty index before merge
- clean/dirty worktree before merge
- dirty index before merge matches contents on remote branch
- changed/unchanged worktree after merge
- changed/unchanged index after merge
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	# Create the above repo
	echo foo > foo &&
	echo bar > bar &&
	echo baz > baz &&
	shit add foo bar baz &&
	shit commit -m initial &&
	echo bazz > baz &&
	shit commit -a -m "second" &&
	shit checkout -b conflict_branch HEAD^ &&
	echo barf > bar &&
	echo bazf > baz &&
	shit commit -a -m "conflict" &&
	shit checkout -b clean_branch HEAD^ &&
	echo bart > bar &&
	shit commit -a -m "clean" &&
	shit checkout main
'

pre_merge_head="$(shit rev-parse HEAD)"

test_expect_success 'fails without MERGE_HEAD (unstarted merge)' '
	test_must_fail shit merge --abort 2>output &&
	test_grep MERGE_HEAD output
'

test_expect_success 'fails without MERGE_HEAD (unstarted merge): .shit/MERGE_HEAD sanity' '
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)"
'

test_expect_success 'fails without MERGE_HEAD (completed merge)' '
	shit merge clean_branch &&
	test ! -f .shit/MERGE_HEAD &&
	# Merge successfully completed
	post_merge_head="$(shit rev-parse HEAD)" &&
	test_must_fail shit merge --abort 2>output &&
	test_grep MERGE_HEAD output
'

test_expect_success 'fails without MERGE_HEAD (completed merge): .shit/MERGE_HEAD sanity' '
	test ! -f .shit/MERGE_HEAD &&
	test "$post_merge_head" = "$(shit rev-parse HEAD)"
'

test_expect_success 'Forget previous merge' '
	shit reset --hard "$pre_merge_head"
'

test_expect_success 'Abort after --no-commit' '
	# Redo merge, but stop before creating merge commit
	shit merge --no-commit clean_branch &&
	test -f .shit/MERGE_HEAD &&
	# Abort non-conflicting merge
	shit merge --abort &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff)" &&
	test -z "$(shit diff --staged)"
'

test_expect_success 'Abort after conflicts' '
	# Create conflicting merge
	test_must_fail shit merge conflict_branch &&
	test -f .shit/MERGE_HEAD &&
	# Abort conflicting merge
	shit merge --abort &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff)" &&
	test -z "$(shit diff --staged)"
'

test_expect_success 'Clean merge with dirty index fails' '
	echo xyzzy >> foo &&
	shit add foo &&
	shit diff --staged > expect &&
	test_must_fail shit merge clean_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff)" &&
	shit diff --staged > actual &&
	test_cmp expect actual
'

test_expect_success 'Conflicting merge with dirty index fails' '
	test_must_fail shit merge conflict_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff)" &&
	shit diff --staged > actual &&
	test_cmp expect actual
'

test_expect_success 'Reset index (but preserve worktree changes)' '
	shit reset "$pre_merge_head" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Abort clean merge with non-conflicting dirty worktree' '
	shit merge --no-commit clean_branch &&
	test -f .shit/MERGE_HEAD &&
	# Abort merge
	shit merge --abort &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Abort conflicting merge with non-conflicting dirty worktree' '
	test_must_fail shit merge conflict_branch &&
	test -f .shit/MERGE_HEAD &&
	# Abort merge
	shit merge --abort &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Reset worktree changes' '
	shit reset --hard "$pre_merge_head"
'

test_expect_success 'Fail clean merge with conflicting dirty worktree' '
	echo xyzzy >> bar &&
	shit diff > expect &&
	test_must_fail shit merge --no-commit clean_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Fail conflicting merge with conflicting dirty worktree' '
	test_must_fail shit merge conflict_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Reset worktree changes' '
	shit reset --hard "$pre_merge_head"
'

test_expect_success 'Fail clean merge with matching dirty worktree' '
	echo bart > bar &&
	shit diff > expect &&
	test_must_fail shit merge --no-commit clean_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_expect_success 'Fail conflicting merge with matching dirty worktree' '
	echo barf > bar &&
	shit diff > expect &&
	test_must_fail shit merge conflict_branch &&
	test ! -f .shit/MERGE_HEAD &&
	test "$pre_merge_head" = "$(shit rev-parse HEAD)" &&
	test -z "$(shit diff --staged)" &&
	shit diff > actual &&
	test_cmp expect actual
'

test_done
