#!/bin/sh

test_description='shit-merge with case-changing rename on case-insensitive file system'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

if ! test_have_prereq CASE_INSENSITIVE_FS
then
	skip_all='skipping case insensitive tests - case sensitive file system'
	test_done
fi

test_expect_success 'merge with case-changing rename' '
	test $(shit config core.ignorecase) = true &&
	>TestCase &&
	shit add TestCase &&
	shit commit -m "add TestCase" &&
	shit tag baseline &&
	shit checkout -b with-camel &&
	>foo &&
	shit add foo &&
	shit commit -m "intervening commit" &&
	shit checkout main &&
	shit rm TestCase &&
	>testcase &&
	shit add testcase &&
	shit commit -m "rename to testcase" &&
	shit checkout with-camel &&
	shit merge main -m "merge" &&
	test_path_is_file testcase
'

test_expect_success 'merge with case-changing rename on both sides' '
	shit checkout main &&
	shit reset --hard baseline &&
	shit branch -D with-camel &&
	shit checkout -b with-camel &&
	shit mv TestCase testcase &&
	shit commit -m "recase on branch" &&
	>foo &&
	shit add foo &&
	shit commit -m "intervening commit" &&
	shit checkout main &&
	shit rm TestCase &&
	>testcase &&
	shit add testcase &&
	shit commit -m "rename to testcase" &&
	shit checkout with-camel &&
	shit merge main -m "merge" &&
	test_path_is_file testcase
'

test_done
