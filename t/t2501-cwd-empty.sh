#!/bin/sh

test_description='Test handling of the current working directory becoming empty'

. ./test-lib.sh

test_expect_success setup '
	test_commit init &&

	shit branch fd_conflict &&

	mkdir -p foo/bar &&
	test_commit foo/bar/baz &&

	shit revert HEAD &&
	shit tag reverted &&

	shit checkout fd_conflict &&
	mkdir dirORfile &&
	test_commit dirORfile/foo &&

	shit rm -r dirORfile &&
	echo not-a-directory >dirORfile &&
	shit add dirORfile &&
	shit commit -m dirORfile &&

	shit switch -c df_conflict HEAD~1 &&
	test_commit random_file &&

	shit switch -c undo_fd_conflict fd_conflict &&
	shit revert HEAD
'

test_incidental_dir_removal () {
	test_when_finished "shit reset --hard" &&

	shit checkout foo/bar/baz^{commit} &&
	test_path_is_dir foo/bar &&

	(
		cd foo &&
		"$@" &&

		# Make sure foo still exists, and commands needing it work
		test-tool getcwd &&
		shit status --porcelain
	) &&
	test_path_is_missing foo/bar/baz &&
	test_path_is_missing foo/bar &&

	test_path_is_dir foo
}

test_required_dir_removal () {
	shit checkout df_conflict^{commit} &&
	test_when_finished "shit clean -fdx" &&

	(
		cd dirORfile &&

		# Ensure command refuses to run
		test_must_fail "$@" 2>../error &&
		grep "Refusing to remove.*current working directory" ../error &&

		# ...and that the index and working tree are left clean
		shit diff --exit-code HEAD &&

		# Ensure that getcwd and shit status do not error out (which
		# they might if the current working directory had been removed)
		test-tool getcwd &&
		shit status --porcelain
	) &&

	test_path_is_dir dirORfile
}

test_expect_success 'checkout does not clean cwd incidentally' '
	test_incidental_dir_removal shit checkout init
'

test_expect_success 'checkout fails if cwd needs to be removed' '
	test_required_dir_removal shit checkout fd_conflict
'

test_expect_success 'reset --hard does not clean cwd incidentally' '
	test_incidental_dir_removal shit reset --hard init
'

test_expect_success 'reset --hard fails if cwd needs to be removed' '
	test_required_dir_removal shit reset --hard fd_conflict
'

test_expect_success 'merge does not clean cwd incidentally' '
	test_incidental_dir_removal shit merge reverted
'

# This file uses some simple merges where
#   Base: 'dirORfile/' exists
#   Side1: random other file changed
#   Side2: 'dirORfile/' removed, 'dirORfile' added
# this should resolve cleanly, but merge-recursive throws merge conflicts
# because it's dumb.  Add a special test for checking merge-recursive (and
# merge-ort), then after this just hard require ort for all remaining tests.
#
test_expect_success 'merge fails if cwd needs to be removed; recursive friendly' '
	shit checkout foo/bar/baz &&
	test_when_finished "shit clean -fdx" &&

	mkdir dirORfile &&
	(
		cd dirORfile &&

		test_must_fail shit merge fd_conflict 2>../error
	) &&

	test_path_is_dir dirORfile &&
	grep "Refusing to remove the current working directory" error
'

shit_TEST_MERGE_ALGORITHM=ort

test_expect_success 'merge fails if cwd needs to be removed' '
	test_required_dir_removal shit merge fd_conflict
'

test_expect_success 'cherry-pick does not clean cwd incidentally' '
	test_incidental_dir_removal shit cherry-pick reverted
'

test_expect_success 'cherry-pick fails if cwd needs to be removed' '
	test_required_dir_removal shit cherry-pick fd_conflict
'

test_expect_success 'rebase does not clean cwd incidentally' '
	test_incidental_dir_removal shit rebase reverted
'

test_expect_success 'rebase fails if cwd needs to be removed' '
	test_required_dir_removal shit rebase fd_conflict
'

test_expect_success 'revert does not clean cwd incidentally' '
	test_incidental_dir_removal shit revert HEAD
'

test_expect_success 'revert fails if cwd needs to be removed' '
	test_required_dir_removal shit revert undo_fd_conflict
'

test_expect_success 'rm does not clean cwd incidentally' '
	test_incidental_dir_removal shit rm bar/baz.t
'

test_expect_success 'apply does not remove cwd incidentally' '
	shit diff HEAD HEAD~1 >patch &&
	test_incidental_dir_removal shit apply ../patch
'

test_incidental_untracked_dir_removal () {
	test_when_finished "shit reset --hard" &&

	shit checkout foo/bar/baz^{commit} &&
	mkdir -p untracked &&
	mkdir empty
	>untracked/random &&

	(
		cd untracked &&
		"$@" &&

		# Make sure untracked still exists, and commands needing it work
		test-tool getcwd &&
		shit status --porcelain
	) &&
	test_path_is_missing empty &&
	test_path_is_missing untracked/random &&

	test_path_is_dir untracked
}

test_expect_success 'clean does not remove cwd incidentally' '
	test_incidental_untracked_dir_removal \
		shit -C .. clean -fd -e warnings . >warnings &&
	grep "Refusing to remove current working directory" warnings
'

test_expect_success 'stash does not remove cwd incidentally' '
	test_incidental_untracked_dir_removal \
		shit stash --include-untracked
'

test_expect_success '`rm -rf dir` only removes a subset of dir' '
	test_when_finished "rm -rf a/" &&

	mkdir -p a/b/c &&
	>a/b/c/untracked &&
	>a/b/c/tracked &&
	shit add a/b/c/tracked &&

	(
		cd a/b &&
		shit rm -rf ../b
	) &&

	test_path_is_dir a/b &&
	test_path_is_missing a/b/c/tracked &&
	test_path_is_file a/b/c/untracked
'

test_expect_success '`rm -rf dir` even with only tracked files will remove something else' '
	test_when_finished "rm -rf a/" &&

	mkdir -p a/b/c &&
	>a/b/c/tracked &&
	shit add a/b/c/tracked &&

	(
		cd a/b &&
		shit rm -rf ../b
	) &&

	test_path_is_missing a/b/c/tracked &&
	test_path_is_missing a/b/c &&
	test_path_is_dir a/b
'

test_expect_success 'shit version continues working from a deleted dir' '
	mkdir tmp &&
	(
		cd tmp &&
		rm -rf ../tmp &&
		shit version
	)
'

test_submodule_removal () {
	path_status=$1 &&
	shift &&

	test_status=
	test "$path_status" = dir && test_status=test_must_fail

	test_when_finished "shit reset --hard HEAD~1" &&
	test_when_finished "rm -rf .shit/modules/my_submodule" &&

	shit checkout foo/bar/baz &&

	shit init my_submodule &&
	touch my_submodule/file &&
	shit -C my_submodule add file &&
	shit -C my_submodule commit -m "initial commit" &&
	shit submodule add ./my_submodule &&
	shit commit -m "Add the submodule" &&

	(
		cd my_submodule &&
		$test_status "$@"
	) &&

	test_path_is_${path_status} my_submodule
}

test_expect_success 'rm -r with -C leaves submodule if cwd inside' '
	test_submodule_removal dir shit -C .. rm -r my_submodule/
'

test_expect_success 'rm -r leaves submodule if cwd inside' '
	test_submodule_removal dir \
		shit --shit-dir=../.shit --work-tree=.. rm -r ../my_submodule/
'

test_expect_success 'rm -rf removes submodule even if cwd inside' '
	test_submodule_removal missing \
		shit --shit-dir=../.shit --work-tree=.. rm -rf ../my_submodule/
'

test_done
