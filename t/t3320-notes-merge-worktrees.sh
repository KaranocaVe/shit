#!/bin/sh
#
# Copyright (c) 2015 Twitter, Inc
#

test_description='Test merging of notes trees in multiple worktrees'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup commit' '
	test_commit tantrum
'

commit_tantrum=$(shit rev-parse tantrum^{commit})

test_expect_success 'setup notes ref (x)' '
	shit config core.notesRef refs/notes/x &&
	shit notes add -m "x notes on tantrum" tantrum
'

test_expect_success 'setup local branch (y)' '
	shit update-ref refs/notes/y refs/notes/x &&
	shit config core.notesRef refs/notes/y &&
	shit notes remove tantrum
'

test_expect_success 'setup remote branch (z)' '
	shit update-ref refs/notes/z refs/notes/x &&
	shit config core.notesRef refs/notes/z &&
	shit notes add -f -m "conflicting notes on tantrum" tantrum
'

test_expect_success 'modify notes ref ourselves (x)' '
	shit config core.notesRef refs/notes/x &&
	shit notes add -f -m "more conflicting notes on tantrum" tantrum
'

test_expect_success 'create some new worktrees' '
	shit worktree add -b newbranch worktree main &&
	shit worktree add -b newbranch2 worktree2 main
'

test_expect_success 'merge z into y fails and sets NOTES_MERGE_REF' '
	shit config core.notesRef refs/notes/y &&
	test_must_fail shit notes merge z &&
	echo "refs/notes/y" >expect &&
	shit symbolic-ref NOTES_MERGE_REF >actual &&
	test_cmp expect actual
'

test_expect_success 'merge z into y while mid-merge in another workdir fails' '
	(
		cd worktree &&
		shit config core.notesRef refs/notes/y &&
		test_must_fail shit notes merge z 2>err &&
		test_grep "a notes merge into refs/notes/y is already in-progress at" err
	) &&
	test_must_fail shit -C worktree symbolic-ref NOTES_MERGE_REF
'

test_expect_success 'merge z into x while mid-merge on y succeeds' '
	(
		cd worktree2 &&
		shit config core.notesRef refs/notes/x &&
		test_must_fail shit notes merge z >out 2>&1 &&
		test_grep "Automatic notes merge failed" out &&
		grep -v "A notes merge into refs/notes/x is already in-progress in" out
	) &&
	echo "refs/notes/x" >expect &&
	shit -C worktree2 symbolic-ref NOTES_MERGE_REF >actual &&
	test_cmp expect actual
'

test_done
