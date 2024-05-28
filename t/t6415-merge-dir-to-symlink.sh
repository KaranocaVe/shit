#!/bin/sh

test_description='merging when a directory was replaced with a symlink'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create a commit where dir a/b changed to symlink' '
	mkdir -p a/b/c a/b-2/c &&
	> a/b/c/d &&
	> a/b-2/c/d &&
	> a/x &&
	shit add -A &&
	shit commit -m base &&
	shit tag start &&
	rm -rf a/b &&
	shit add -A &&
	test_ln_s_add b-2 a/b &&
	shit commit -m "dir to symlink"
'

test_expect_success 'checkout does not clobber untracked symlink' '
	shit checkout HEAD^0 &&
	shit reset --hard main &&
	shit rm --cached a/b &&
	shit commit -m "untracked symlink remains" &&
	test_must_fail shit checkout start^0 &&
	shit clean -fd    # Do not leave the untracked symlink in the way
'

test_expect_success 'a/b-2/c/d is kept when clobbering symlink b' '
	shit checkout HEAD^0 &&
	shit reset --hard main &&
	shit rm --cached a/b &&
	shit commit -m "untracked symlink remains" &&
	shit checkout -f start^0 &&
	test_path_is_file a/b-2/c/d &&
	shit clean -fd    # Do not leave the untracked symlink in the way
'

test_expect_success 'checkout should not have deleted a/b-2/c/d' '
	shit checkout HEAD^0 &&
	shit reset --hard main &&
	 shit checkout start^0 &&
	 test_path_is_file a/b-2/c/d
'

test_expect_success 'setup for merge test' '
	shit reset --hard &&
	test_path_is_file a/b-2/c/d &&
	echo x > a/x &&
	shit add a/x &&
	shit commit -m x &&
	shit tag baseline
'

test_expect_success 'Handle D/F conflict, do not lose a/b-2/c/d in merge (resolve)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	shit merge -s resolve main &&
	test_path_is_file a/b-2/c/d
'

test_expect_success SYMLINKS 'a/b was resolved as symlink' '
	test -h a/b
'

test_expect_success 'Handle D/F conflict, do not lose a/b-2/c/d in merge (recursive)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	shit merge -s recursive main &&
	test_path_is_file a/b-2/c/d
'

test_expect_success SYMLINKS 'a/b was resolved as symlink' '
	test -h a/b
'

test_expect_success 'Handle F/D conflict, do not lose a/b-2/c/d in merge (resolve)' '
	shit reset --hard &&
	shit checkout main^0 &&
	shit merge -s resolve baseline^0 &&
	test_path_is_file a/b-2/c/d
'

test_expect_success SYMLINKS 'a/b was resolved as symlink' '
	test -h a/b
'

test_expect_success 'Handle F/D conflict, do not lose a/b-2/c/d in merge (recursive)' '
	shit reset --hard &&
	shit checkout main^0 &&
	shit merge -s recursive baseline^0 &&
	test_path_is_file a/b-2/c/d
'

test_expect_success SYMLINKS 'a/b was resolved as symlink' '
	test -h a/b
'

test_expect_failure 'do not lose untracked in merge (resolve)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	>a/b/c/e &&
	test_must_fail shit merge -s resolve main &&
	test_path_is_file a/b/c/e &&
	test_path_is_file a/b-2/c/d
'

test_expect_success 'do not lose untracked in merge (recursive)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	>a/b/c/e &&
	test_must_fail shit merge -s recursive main &&
	test_path_is_file a/b/c/e &&
	test_path_is_file a/b-2/c/d
'

test_expect_success 'do not lose modifications in merge (resolve)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	echo more content >>a/b/c/d &&
	test_must_fail shit merge -s resolve main
'

test_expect_success 'do not lose modifications in merge (recursive)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	echo more content >>a/b/c/d &&
	test_must_fail shit merge -s recursive main
'

test_expect_success 'setup a merge where dir a/b-2 changed to symlink' '
	shit reset --hard &&
	shit checkout start^0 &&
	rm -rf a/b-2 &&
	shit add -A &&
	test_ln_s_add b a/b-2 &&
	shit commit -m "dir a/b-2 to symlink" &&
	shit tag test2
'

test_expect_success 'merge should not have D/F conflicts (resolve)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	shit merge -s resolve test2 &&
	test_path_is_file a/b/c/d
'

test_expect_success SYMLINKS 'a/b-2 was resolved as symlink' '
	test -h a/b-2
'

test_expect_success 'merge should not have D/F conflicts (recursive)' '
	shit reset --hard &&
	shit checkout baseline^0 &&
	shit merge -s recursive test2 &&
	test_path_is_file a/b/c/d
'

test_expect_success SYMLINKS 'a/b-2 was resolved as symlink' '
	test -h a/b-2
'

test_expect_success 'merge should not have F/D conflicts (recursive)' '
	shit reset --hard &&
	shit checkout -b foo test2 &&
	shit merge -s recursive baseline^0 &&
	test_path_is_file a/b/c/d
'

test_expect_success SYMLINKS 'a/b-2 was resolved as symlink' '
	test -h a/b-2
'

test_done
