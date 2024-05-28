#!/bin/sh

test_description='test shit worktree move, remove, lock and unlock'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit init &&
	shit worktree add source &&
	shit worktree list --porcelain >out &&
	grep "^worktree" out >actual &&
	cat <<-EOF >expected &&
	worktree $(pwd)
	worktree $(pwd)/source
	EOF
	test_cmp expected actual
'

test_expect_success 'lock main worktree' '
	test_must_fail shit worktree lock .
'

test_expect_success 'lock linked worktree' '
	shit worktree lock --reason hahaha source &&
	echo hahaha >expected &&
	test_cmp expected .shit/worktrees/source/locked
'

test_expect_success 'lock linked worktree from another worktree' '
	rm .shit/worktrees/source/locked &&
	shit worktree add elsewhere &&
	shit -C elsewhere worktree lock --reason hahaha ../source &&
	echo hahaha >expected &&
	test_cmp expected .shit/worktrees/source/locked
'

test_expect_success 'lock worktree twice' '
	test_must_fail shit worktree lock source &&
	echo hahaha >expected &&
	test_cmp expected .shit/worktrees/source/locked
'

test_expect_success 'lock worktree twice (from the locked worktree)' '
	test_must_fail shit -C source worktree lock . &&
	echo hahaha >expected &&
	test_cmp expected .shit/worktrees/source/locked
'

test_expect_success 'unlock main worktree' '
	test_must_fail shit worktree unlock .
'

test_expect_success 'unlock linked worktree' '
	shit worktree unlock source &&
	test_path_is_missing .shit/worktrees/source/locked
'

test_expect_success 'unlock worktree twice' '
	test_must_fail shit worktree unlock source &&
	test_path_is_missing .shit/worktrees/source/locked
'

test_expect_success 'move non-worktree' '
	mkdir abc &&
	test_must_fail shit worktree move abc def
'

test_expect_success 'move locked worktree' '
	shit worktree lock source &&
	test_when_finished "shit worktree unlock source" &&
	test_must_fail shit worktree move source destination
'

test_expect_success 'move worktree' '
	shit worktree move source destination &&
	test_path_is_missing source &&
	shit worktree list --porcelain >out &&
	grep "^worktree.*/destination$" out &&
	! grep "^worktree.*/source$" out &&
	shit -C destination log --format=%s >actual2 &&
	echo init >expected2 &&
	test_cmp expected2 actual2
'

test_expect_success 'move main worktree' '
	test_must_fail shit worktree move . def
'

test_expect_success 'move worktree to another dir' '
	mkdir some-dir &&
	shit worktree move destination some-dir &&
	test_when_finished "shit worktree move some-dir/destination destination" &&
	test_path_is_missing destination &&
	shit worktree list --porcelain >out &&
	grep "^worktree.*/some-dir/destination$" out &&
	shit -C some-dir/destination log --format=%s >actual2 &&
	echo init >expected2 &&
	test_cmp expected2 actual2
'

test_expect_success 'move locked worktree (force)' '
	test_when_finished "
		shit worktree unlock flump || :
		shit worktree remove flump || :
		shit worktree unlock ploof || :
		shit worktree remove ploof || :
		" &&
	shit worktree add --detach flump &&
	shit worktree lock flump &&
	test_must_fail shit worktree move flump ploof" &&
	test_must_fail shit worktree move --force flump ploof" &&
	shit worktree move --force --force flump ploof
'

test_expect_success 'refuse to move worktree atop existing path' '
	>bobble &&
	shit worktree add --detach beeble &&
	test_must_fail shit worktree move beeble bobble
'

test_expect_success 'move atop existing but missing worktree' '
	shit worktree add --detach gnoo &&
	shit worktree add --detach pneu &&
	rm -fr pneu &&
	test_must_fail shit worktree move gnoo pneu &&
	shit worktree move --force gnoo pneu &&

	shit worktree add --detach nu &&
	shit worktree lock nu &&
	rm -fr nu &&
	test_must_fail shit worktree move pneu nu &&
	test_must_fail shit worktree --force move pneu nu &&
	shit worktree move --force --force pneu nu
'

test_expect_success 'move a repo with uninitialized submodule' '
	shit init withsub &&
	(
		cd withsub &&
		test_commit initial &&
		shit -c protocol.file.allow=always \
			submodule add "$PWD"/.shit sub &&
		shit commit -m withsub &&
		shit worktree add second HEAD &&
		shit worktree move second third
	)
'

test_expect_success 'not move a repo with initialized submodule' '
	(
		cd withsub &&
		shit -c protocol.file.allow=always -C third submodule update &&
		test_must_fail shit worktree move third forth
	)
'

test_expect_success 'remove main worktree' '
	test_must_fail shit worktree remove .
'

test_expect_success 'remove locked worktree' '
	shit worktree lock destination &&
	test_when_finished "shit worktree unlock destination" &&
	test_must_fail shit worktree remove destination
'

test_expect_success 'remove worktree with dirty tracked file' '
	echo dirty >>destination/init.t &&
	test_when_finished "shit -C destination checkout init.t" &&
	test_must_fail shit worktree remove destination
'

test_expect_success 'remove worktree with untracked file' '
	: >destination/untracked &&
	test_must_fail shit worktree remove destination
'

test_expect_success 'force remove worktree with untracked file' '
	shit worktree remove --force destination &&
	test_path_is_missing destination
'

test_expect_success 'remove missing worktree' '
	shit worktree add to-be-gone &&
	test -d .shit/worktrees/to-be-gone &&
	mv to-be-gone gone &&
	shit worktree remove to-be-gone &&
	test_path_is_missing .shit/worktrees/to-be-gone
'

test_expect_success 'NOT remove missing-but-locked worktree' '
	shit worktree add gone-but-locked &&
	shit worktree lock gone-but-locked &&
	test -d .shit/worktrees/gone-but-locked &&
	mv gone-but-locked really-gone-now &&
	test_must_fail shit worktree remove gone-but-locked &&
	test_path_is_dir .shit/worktrees/gone-but-locked
'

test_expect_success 'proper error when worktree not found' '
	for i in noodle noodle/bork
	do
		test_must_fail shit worktree lock $i 2>err &&
		test_grep "not a working tree" err || return 1
	done
'

test_expect_success 'remove locked worktree (force)' '
	shit worktree add --detach gumby &&
	test_when_finished "shit worktree remove gumby || :" &&
	shit worktree lock gumby &&
	test_when_finished "shit worktree unlock gumby || :" &&
	test_must_fail shit worktree remove gumby &&
	test_must_fail shit worktree remove --force gumby &&
	shit worktree remove --force --force gumby
'

test_expect_success 'remove cleans up .shit/worktrees when empty' '
	shit init moog &&
	(
		cd moog &&
		test_commit bim &&
		shit worktree add --detach goom &&
		test_path_exists .shit/worktrees &&
		shit worktree remove goom &&
		test_path_is_missing .shit/worktrees
	)
'

test_expect_success 'remove a repo with uninitialized submodule' '
	test_config_global protocol.file.allow always &&
	(
		cd withsub &&
		shit worktree add to-remove HEAD &&
		shit worktree remove to-remove
	)
'

test_expect_success 'not remove a repo with initialized submodule' '
	test_config_global protocol.file.allow always &&
	(
		cd withsub &&
		shit worktree add to-remove HEAD &&
		shit -C to-remove submodule update &&
		test_must_fail shit worktree remove to-remove
	)
'

test_done
