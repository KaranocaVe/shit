#!/bin/sh
#
# Copyright (c) 2005 Amos Waterland
#

test_description='shit rebase assorted tests

This test runs shit rebase and checks that the author information is not lost
among other things.
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

shit_AUTHOR_NAME=author@name
shit_AUTHOR_EMAIL=bogus@email@address
export shit_AUTHOR_NAME shit_AUTHOR_EMAIL

test_expect_success 'prepare repository with topic branches' '
	test_commit "Add A." A First First &&
	shit checkout -b force-3way &&
	echo Dummy >Y &&
	shit update-index --add Y &&
	shit commit -m "Add Y." &&
	shit checkout -b filemove &&
	shit reset --soft main &&
	mkdir D &&
	shit mv A D/A &&
	shit commit -m "Move A." &&
	shit checkout -b my-topic-branch main &&
	test_commit "Add B." B Second Second &&
	shit checkout -f main &&
	echo Third >>A &&
	shit update-index A &&
	shit commit -m "Modify A." &&
	shit checkout -b side my-topic-branch &&
	echo Side >>C &&
	shit add C &&
	shit commit -m "Add C" &&
	shit checkout -f my-topic-branch &&
	shit tag topic
'

test_expect_success 'rebase on dirty worktree' '
	echo dirty >>A &&
	test_must_fail shit rebase main
'

test_expect_success 'rebase on dirty cache' '
	shit add A &&
	test_must_fail shit rebase main
'

test_expect_success 'rebase against main' '
	shit reset --hard HEAD &&
	shit rebase main
'

test_expect_success 'rebase sets ORIG_HEAD to pre-rebase state' '
	shit checkout -b orig-head topic &&
	pre="$(shit rev-parse --verify HEAD)" &&
	shit rebase main &&
	test_cmp_rev "$pre" ORIG_HEAD &&
	test_cmp_rev ! "$pre" HEAD
'

test_expect_success 'rebase, with <onto> and <upstream> specified as :/quuxery' '
	test_when_finished "shit branch -D torebase" &&
	shit checkout -b torebase my-topic-branch^ &&
	upstream=$(shit rev-parse ":/Add B") &&
	onto=$(shit rev-parse ":/Add A") &&
	shit rebase --onto $onto $upstream &&
	shit reset --hard my-topic-branch^ &&
	shit rebase --onto ":/Add A" ":/Add B" &&
	shit checkout my-topic-branch
'

test_expect_success 'the rebase operation should not have destroyed author information' '
	! (shit log | grep "Author:" | grep "<>")
'

test_expect_success 'the rebase operation should not have destroyed author information (2)' "
	shit log -1 |
	grep 'Author: $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL>'
"

test_expect_success 'HEAD was detached during rebase' '
	test $(shit rev-parse HEAD@{1}) != $(shit rev-parse my-topic-branch@{1})
'

test_expect_success 'rebase from ambiguous branch name' '
	shit checkout -b topic side &&
	shit rebase main
'

test_expect_success 'rebase off of the previous branch using "-"' '
	shit checkout main &&
	shit checkout HEAD^ &&
	shit rebase @{-1} >expect.messages &&
	shit merge-base main HEAD >expect.forkpoint &&

	shit checkout main &&
	shit checkout HEAD^ &&
	shit rebase - >actual.messages &&
	shit merge-base main HEAD >actual.forkpoint &&

	test_cmp expect.forkpoint actual.forkpoint &&
	# the next one is dubious---we may want to say "-",
	# instead of @{-1}, in the message
	test_cmp expect.messages actual.messages
'

test_expect_success 'rebase a single mode change' '
	shit checkout main &&
	shit branch -D topic &&
	echo 1 >X &&
	shit add X &&
	test_tick &&
	shit commit -m prepare &&
	shit checkout -b modechange HEAD^ &&
	echo 1 >X &&
	shit add X &&
	test_chmod +x A &&
	test_tick &&
	shit commit -m modechange &&
	shit_TRACE=1 shit rebase main
'

test_expect_success 'rebase is not broken by diff.renames' '
	test_config diff.renames copies &&
	shit checkout filemove &&
	shit_TRACE=1 shit rebase force-3way
'

test_expect_success 'setup: recover' '
	test_might_fail shit rebase --abort &&
	shit reset --hard &&
	shit checkout modechange
'

test_expect_success 'Show verbose error when HEAD could not be detached' '
	>B &&
	test_when_finished "rm -f B" &&
	test_must_fail shit rebase topic 2>output.err >output.out &&
	test_grep "The following untracked working tree files would be overwritten by checkout:" output.err &&
	test_grep B output.err
'

test_expect_success 'fail when upstream arg is missing and not on branch' '
	shit checkout topic &&
	test_must_fail shit rebase
'

test_expect_success 'fail when upstream arg is missing and not configured' '
	shit checkout -b no-config topic &&
	test_must_fail shit rebase
'

test_expect_success 'rebase works with format.useAutoBase' '
	test_config format.useAutoBase true &&
	shit checkout topic &&
	shit rebase main
'

test_expect_success 'default to common base in @{upstream}s reflog if no upstream arg (--merge)' '
	shit checkout -b default-base main &&
	shit checkout -b default topic &&
	shit config branch.default.remote . &&
	shit config branch.default.merge refs/heads/default-base &&
	shit rebase --merge &&
	shit rev-parse --verify default-base >expect &&
	shit rev-parse default~1 >actual &&
	test_cmp expect actual &&
	shit checkout default-base &&
	shit reset --hard HEAD^ &&
	shit checkout default &&
	shit rebase --merge &&
	shit rev-parse --verify default-base >expect &&
	shit rev-parse default~1 >actual &&
	test_cmp expect actual
'

test_expect_success 'default to common base in @{upstream}s reflog if no upstream arg (--apply)' '
	shit checkout -B default-base main &&
	shit checkout -B default topic &&
	shit config branch.default.remote . &&
	shit config branch.default.merge refs/heads/default-base &&
	shit rebase --apply &&
	shit rev-parse --verify default-base >expect &&
	shit rev-parse default~1 >actual &&
	test_cmp expect actual &&
	shit checkout default-base &&
	shit reset --hard HEAD^ &&
	shit checkout default &&
	shit rebase --apply &&
	shit rev-parse --verify default-base >expect &&
	shit rev-parse default~1 >actual &&
	test_cmp expect actual
'

test_expect_success 'cherry-picked commits and fork-point work together' '
	shit checkout default-base &&
	echo Amended >A &&
	shit commit -a --no-edit --amend &&
	test_commit B B &&
	test_commit new_B B "New B" &&
	test_commit C C &&
	shit checkout default &&
	shit reset --hard default-base@{4} &&
	test_commit D D &&
	shit cherry-pick -2 default-base^ &&
	test_commit final_B B "Final B" &&
	shit rebase &&
	echo Amended >expect &&
	test_cmp expect A &&
	echo "Final B" >expect &&
	test_cmp expect B &&
	echo C >expect &&
	test_cmp expect C &&
	echo D >expect &&
	test_cmp expect D
'

test_expect_success 'rebase --apply -q is quiet' '
	shit checkout -b quiet topic &&
	shit rebase --apply -q main >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'rebase --merge -q is quiet' '
	shit checkout -B quiet topic &&
	shit rebase --merge -q main >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'Rebase a commit that sprinkles CRs in' '
	(
		echo "One" &&
		echo "TwoQ" &&
		echo "Three" &&
		echo "FQur" &&
		echo "Five"
	) | q_to_cr >CR &&
	shit add CR &&
	test_tick &&
	shit commit -a -m "A file with a line with CR" &&
	shit tag file-with-cr &&
	shit checkout HEAD^0 &&
	shit rebase --onto HEAD^^ HEAD^ &&
	shit diff --exit-code file-with-cr:CR HEAD:CR
'

test_expect_success 'rebase can copy notes' '
	shit config notes.rewrite.rebase true &&
	shit config notes.rewriteRef "refs/notes/*" &&
	test_commit n1 &&
	test_commit n2 &&
	test_commit n3 &&
	shit notes add -m"a note" n3 &&
	shit rebase --onto n1 n2 &&
	test "a note" = "$(shit notes show HEAD)"
'

test_expect_success 'rebase -m can copy notes' '
	shit reset --hard n3 &&
	shit rebase -m --onto n1 n2 &&
	test "a note" = "$(shit notes show HEAD)"
'

test_expect_success 'rebase commit with an ancient timestamp' '
	shit reset --hard &&

	>old.one && shit add old.one && test_tick &&
	shit commit --date="@12345 +0400" -m "Old one" &&
	>old.two && shit add old.two && test_tick &&
	shit commit --date="@23456 +0500" -m "Old two" &&
	>old.three && shit add old.three && test_tick &&
	shit commit --date="@34567 +0600" -m "Old three" &&

	shit cat-file commit HEAD^^ >actual &&
	grep "author .* 12345 +0400$" actual &&
	shit cat-file commit HEAD^ >actual &&
	grep "author .* 23456 +0500$" actual &&
	shit cat-file commit HEAD >actual &&
	grep "author .* 34567 +0600$" actual &&

	shit rebase --onto HEAD^^ HEAD^ &&

	shit cat-file commit HEAD >actual &&
	grep "author .* 34567 +0600$" actual
'

test_expect_success 'rebase with "From " line in commit message' '
	shit checkout -b preserve-from main~1 &&
	cat >From_.msg <<EOF &&
Somebody embedded an mbox in a commit message

This is from so-and-so:

From a@b Mon Sep 17 00:00:00 2001
From: John Doe <nobody@example.com>
Date: Sat, 11 Nov 2017 00:00:00 +0000
Subject: not this message

something
EOF
	>From_ &&
	shit add From_ &&
	shit commit -F From_.msg &&
	shit rebase main &&
	shit log -1 --pretty=format:%B >out &&
	test_cmp From_.msg out
'

test_expect_success 'rebase --apply and --show-current-patch' '
	test_create_repo conflict-apply &&
	(
		cd conflict-apply &&
		test_commit init &&
		echo one >>init.t &&
		shit commit -a -m one &&
		echo two >>init.t &&
		shit commit -a -m two &&
		shit tag two &&
		test_must_fail shit rebase --apply -f --onto init HEAD^ &&
		shit_TRACE=1 shit rebase --show-current-patch >/dev/null 2>stderr &&
		grep "show.*$(shit rev-parse two)" stderr
	)
'

test_expect_success 'rebase --apply and .shitattributes' '
	test_create_repo attributes &&
	(
		cd attributes &&
		test_commit init &&
		shit config filter.test.clean "sed -e '\''s/smudged/clean/g'\''" &&
		shit config filter.test.smudge "sed -e '\''s/clean/smudged/g'\''" &&

		test_commit second &&
		shit checkout -b test HEAD^ &&

		echo "*.txt filter=test" >.shitattributes &&
		shit add .shitattributes &&
		test_commit third &&

		echo "This text is smudged." >a.txt &&
		shit add a.txt &&
		test_commit fourth &&

		shit checkout -b removal HEAD^ &&
		shit rm .shitattributes &&
		shit add -u &&
		test_commit fifth &&
		shit cherry-pick test &&

		shit checkout test &&
		shit rebase main &&
		grep "smudged" a.txt &&

		shit checkout removal &&
		shit reset --hard &&
		shit rebase main &&
		grep "clean" a.txt
	)
'

test_expect_success 'rebase--merge.sh and --show-current-patch' '
	test_create_repo conflict-merge &&
	(
		cd conflict-merge &&
		test_commit init &&
		echo one >>init.t &&
		shit commit -a -m one &&
		echo two >>init.t &&
		shit commit -a -m two &&
		shit tag two &&
		test_must_fail shit rebase --merge --onto init HEAD^ &&
		shit rebase --show-current-patch >actual.patch &&
		shit_TRACE=1 shit rebase --show-current-patch >/dev/null 2>stderr &&
		grep "show.*REBASE_HEAD" stderr &&
		test "$(shit rev-parse REBASE_HEAD)" = "$(shit rev-parse two)"
	)
'

test_expect_success 'switch to branch checked out here' '
	shit checkout main &&
	shit rebase main main
'

test_expect_success 'switch to branch checked out elsewhere fails' '
	test_when_finished "
		shit worktree remove wt1 &&
		shit worktree remove wt2 &&
		shit branch -d shared
	" &&
	shit worktree add wt1 -b shared &&
	shit worktree add wt2 -f shared &&
	# we test in both worktrees to ensure that works
	# as expected with "first" and "next" worktrees
	test_must_fail shit -C wt1 rebase shared shared &&
	test_must_fail shit -C wt2 rebase shared shared
'

test_expect_success 'switch to branch not checked out' '
	shit checkout main &&
	shit branch other &&
	shit rebase main other
'

test_expect_success 'switch to non-branch detaches HEAD' '
	shit checkout main &&
	old_main=$(shit rev-parse HEAD) &&
	shit rebase First Second^0 &&
	test_cmp_rev HEAD Second &&
	test_cmp_rev main $old_main &&
	test_must_fail shit symbolic-ref HEAD
'

test_expect_success 'refuse to switch to branch checked out elsewhere' '
	shit checkout main &&
	shit worktree add wt &&
	test_must_fail shit -C wt rebase main main 2>err &&
	test_grep "already used by worktree at" err
'

test_expect_success 'rebase when inside worktree subdirectory' '
	shit init main-wt &&
	(
		cd main-wt &&
		shit commit --allow-empty -m "initial" &&
		mkdir -p foo/bar &&
		test_commit foo/bar/baz &&
		mkdir -p a/b &&
		test_commit a/b/c &&
		# create another branch for our other worktree
		shit branch other &&
		shit worktree add ../other-wt other &&
		cd ../other-wt &&
		# create and cd into a subdirectory
		mkdir -p random/dir &&
		cd random/dir &&
		# now do the rebase
		shit rebase --onto HEAD^^ HEAD^  # drops the HEAD^ commit
	)
'

test_done
