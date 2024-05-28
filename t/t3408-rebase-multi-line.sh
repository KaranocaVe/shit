#!/bin/sh

test_description='rebasing a commit with multi-line first paragraph.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&

	echo hello >file &&
	test_tick &&
	shit commit -a -m "A sample commit log message that has a long
summary that spills over multiple lines.

But otherwise with a sane description." &&

	shit branch side &&

	shit reset --hard HEAD^ &&
	>elif &&
	shit add elif &&
	test_tick &&
	shit commit -m second &&

	shit checkout -b side2 &&
	>afile &&
	shit add afile &&
	test_tick &&
	shit commit -m third &&
	echo hello >afile &&
	test_tick &&
	shit commit -a -m fourth &&
	shit checkout -b side-merge &&
	shit reset --hard HEAD^^ &&
	shit merge --no-ff -m "A merge commit log message that has a long
summary that spills over multiple lines.

But otherwise with a sane description." side2 &&
	shit branch side-merge-original
'

test_expect_success rebase '

	shit checkout side &&
	shit rebase main &&
	shit cat-file commit HEAD | sed -e "1,/^\$/d" >actual &&
	shit cat-file commit side@{1} | sed -e "1,/^\$/d" >expect &&
	test_cmp expect actual

'
test_done
