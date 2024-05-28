#!/bin/sh

test_description='merge conflict in crlf repo

		b---M
	       /   /
	initial---a

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit config core.autocrlf true &&
	echo foo | append_cr >file &&
	shit add file &&
	shit commit -m "Initial" &&
	shit tag initial &&
	shit branch side &&
	echo line from a | append_cr >file &&
	shit commit -m "add line from a" file &&
	shit tag a &&
	shit checkout side &&
	echo line from b | append_cr >file &&
	shit commit -m "add line from b" file &&
	shit tag b &&
	shit checkout main
'

test_expect_success 'Check "ours" is CRLF' '
	shit reset --hard initial &&
	shit merge side -s ours &&
	remove_cr <file | append_cr >file.temp &&
	test_cmp file file.temp
'

test_expect_success 'Check that conflict file is CRLF' '
	shit reset --hard a &&
	test_must_fail shit merge side &&
	remove_cr <file | append_cr >file.temp &&
	test_cmp file file.temp
'

test_done
