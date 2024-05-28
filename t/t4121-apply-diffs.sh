#!/bin/sh

test_description='shit apply for contextually independent diffs'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

echo '1
2
3
4
5
6
7
8' >file

test_expect_success 'setup' \
	'shit add file &&
	shit commit -q -m 1 &&
	shit checkout -b test &&
	mv file file.tmp &&
	echo 0 >file &&
	cat file.tmp >>file &&
	rm file.tmp &&
	shit commit -a -q -m 2 &&
	echo 9 >>file &&
	shit commit -a -q -m 3 &&
	shit checkout main'

test_expect_success \
	'check if contextually independent diffs for the same file apply' \
	'( shit diff test~2 test~1 && shit diff test~1 test~0 )| shit apply'

test_done
