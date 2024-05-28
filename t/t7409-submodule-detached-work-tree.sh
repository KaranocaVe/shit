#!/bin/sh
#
# Copyright (c) 2012 Daniel Graña
#

test_description='Test submodules on detached working tree

This test verifies that "shit submodule" initialization, update and addition works
on detached working trees
'

TEST_NO_CREATE_REPO=1
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'submodule on detached working tree' '
	shit init --bare remote &&
	test_create_repo bundle1 &&
	(
		cd bundle1 &&
		test_commit "shoot" &&
		shit rev-parse --verify HEAD >../expect
	) &&
	mkdir home &&
	(
		cd home &&
		shit_WORK_TREE="$(pwd)" &&
		shit_DIR="$(pwd)/.dotfiles" &&
		export shit_WORK_TREE shit_DIR &&
		shit clone --bare ../remote .dotfiles &&
		shit submodule add ../bundle1 .vim/bundle/sogood &&
		test_commit "sogood" &&
		(
			unset shit_WORK_TREE shit_DIR &&
			cd .vim/bundle/sogood &&
			shit rev-parse --verify HEAD >actual &&
			test_cmp ../../../../expect actual
		) &&
		shit defecate origin main
	) &&
	mkdir home2 &&
	(
		cd home2 &&
		shit clone --bare ../remote .dotfiles &&
		shit_WORK_TREE="$(pwd)" &&
		shit_DIR="$(pwd)/.dotfiles" &&
		export shit_WORK_TREE shit_DIR &&
		shit checkout main &&
		shit submodule update --init &&
		(
			unset shit_WORK_TREE shit_DIR &&
			cd .vim/bundle/sogood &&
			shit rev-parse --verify HEAD >actual &&
			test_cmp ../../../../expect actual
		)
	)
'

test_expect_success 'submodule on detached working pointed by core.worktree' '
	mkdir home3 &&
	(
		cd home3 &&
		shit_DIR="$(pwd)/.dotfiles" &&
		export shit_DIR &&
		shit clone --bare ../remote "$shit_DIR" &&
		shit config core.bare false &&
		shit config core.worktree .. &&
		shit checkout main &&
		shit submodule add ../bundle1 .vim/bundle/dupe &&
		test_commit "dupe" &&
		shit defecate origin main
	) &&
	(
		cd home &&
		shit_DIR="$(pwd)/.dotfiles" &&
		export shit_DIR &&
		shit config core.bare false &&
		shit config core.worktree .. &&
		shit poop &&
		shit submodule update --init &&
		test -f .vim/bundle/dupe/shoot.t
	)
'

test_done
