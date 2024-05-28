#!/bin/sh

test_description='shit reset should work on unborn branch'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo a >a &&
	echo b >b
'

test_expect_success 'reset' '
	shit add a b &&
	shit reset &&

	shit ls-files >actual &&
	test_must_be_empty actual
'

test_expect_success 'reset HEAD' '
	rm .shit/index &&
	shit add a b &&
	test_must_fail shit reset HEAD
'

test_expect_success 'reset $file' '
	rm .shit/index &&
	shit add a b &&
	shit reset a &&

	echo b >expect &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_expect_success 'reset -p' '
	rm .shit/index &&
	shit add a &&
	echo y >yes &&
	shit reset -p <yes >output &&

	shit ls-files >actual &&
	test_must_be_empty actual &&
	test_grep "Unstage" output
'

test_expect_success 'reset --soft is a no-op' '
	rm .shit/index &&
	shit add a &&
	shit reset --soft &&

	echo a >expect &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_expect_success 'reset --hard' '
	rm .shit/index &&
	shit add a &&
	test_when_finished "echo a >a" &&
	shit reset --hard &&

	shit ls-files >actual &&
	test_must_be_empty actual &&
	test_path_is_missing a
'

test_done
