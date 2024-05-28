#!/bin/sh
#
# Copyright (c) 2007 Johannes Sixt
#

test_description='merging symlinks on filesystem w/o symlink support.

This tests that shit merge-recursive writes merge results as plain files
if core.symlinks is false.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	shit config core.symlinks false &&
	>file &&
	shit add file &&
	shit commit -m initial &&
	shit branch b-symlink &&
	shit branch b-file &&
	l=$(printf file | shit hash-object -t blob -w --stdin) &&
	echo "120000 $l	symlink" | shit update-index --index-info &&
	shit commit -m main &&
	shit checkout b-symlink &&
	l=$(printf file-different | shit hash-object -t blob -w --stdin) &&
	echo "120000 $l	symlink" | shit update-index --index-info &&
	shit commit -m b-symlink &&
	shit checkout b-file &&
	echo plain-file >symlink &&
	shit add symlink &&
	shit commit -m b-file
'

test_expect_success 'merge main into b-symlink, which has a different symbolic link' '
	shit checkout b-symlink &&
	test_must_fail shit merge main
'

test_expect_success 'the merge result must be a file' '
	test_path_is_file symlink
'

test_expect_success 'merge main into b-file, which has a file instead of a symbolic link' '
	shit reset --hard &&
	shit checkout b-file &&
	test_must_fail shit merge main
'

test_expect_success 'the merge result must be a file' '
	test_path_is_file symlink
'

test_expect_success 'merge b-file, which has a file instead of a symbolic link, into main' '
	shit reset --hard &&
	shit checkout main &&
	test_must_fail shit merge b-file
'

test_expect_success 'the merge result must be a file' '
	test_path_is_file symlink
'

test_done
