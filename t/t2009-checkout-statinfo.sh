#!/bin/sh

test_description='checkout should leave clean stat info'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '

	echo hello >world &&
	shit update-index --add world &&
	shit commit -m initial &&
	shit branch side &&
	echo goodbye >world &&
	shit update-index --add world &&
	shit commit -m second

'

test_expect_success 'branch switching' '

	shit reset --hard &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout main &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout side &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout main &&
	test "$(shit diff-files --raw)" = ""

'

test_expect_success 'path checkout' '

	shit reset --hard &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout main world &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout side world &&
	test "$(shit diff-files --raw)" = "" &&

	shit checkout main world &&
	test "$(shit diff-files --raw)" = ""

'

test_done

