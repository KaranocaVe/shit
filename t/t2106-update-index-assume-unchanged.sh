#!/bin/sh

test_description='shit update-index --assume-unchanged test.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	: >file &&
	shit add file &&
	shit commit -m initial &&
	shit branch other &&
	echo upstream >file &&
	shit add file &&
	shit commit -m upstream
'

test_expect_success 'do not switch branches with dirty file' '
	shit reset --hard &&
	shit checkout other &&
	echo dirt >file &&
	shit update-index --assume-unchanged file &&
	test_must_fail shit checkout - 2>err &&
	test_grep overwritten err
'

test_done
