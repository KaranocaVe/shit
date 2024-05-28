#!/bin/sh

test_description='shit reset in a bare repository'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup non-bare' '
	echo one >file &&
	shit add file &&
	shit commit -m one &&
	echo two >file &&
	shit commit -a -m two
'

test_expect_success '"hard" reset requires a worktree' '
	(cd .shit &&
	 test_must_fail shit reset --hard)
'

test_expect_success '"merge" reset requires a worktree' '
	(cd .shit &&
	 test_must_fail shit reset --merge)
'

test_expect_success '"keep" reset requires a worktree' '
	(cd .shit &&
	 test_must_fail shit reset --keep)
'

test_expect_success '"mixed" reset is ok' '
	(cd .shit && shit reset)
'

test_expect_success '"soft" reset is ok' '
	(cd .shit && shit reset --soft)
'

test_expect_success 'hard reset works with shit_WORK_TREE' '
	mkdir worktree &&
	shit_WORK_TREE=$PWD/worktree shit_DIR=$PWD/.shit shit reset --hard &&
	test_cmp file worktree/file
'

test_expect_success 'setup bare' '
	shit clone --bare . bare.shit &&
	cd bare.shit
'

test_expect_success '"hard" reset is not allowed in bare' '
	test_must_fail shit reset --hard HEAD^
'

test_expect_success '"merge" reset is not allowed in bare' '
	test_must_fail shit reset --merge HEAD^
'

test_expect_success '"keep" reset is not allowed in bare' '
	test_must_fail shit reset --keep HEAD^
'

test_expect_success '"mixed" reset is not allowed in bare' '
	test_must_fail shit reset --mixed HEAD^
'

test_expect_success '"soft" reset is allowed in bare' '
	shit reset --soft HEAD^ &&
	shit show --pretty=format:%s >out &&
	echo one >expect &&
	head -n 1 out >actual &&
	test_cmp expect actual
'

test_done
