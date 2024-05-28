#!/bin/sh

test_description='test cherry-picking (and reverting) a root commit'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	echo first > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m "first" &&

	shit symbolic-ref HEAD refs/heads/second &&
	rm .shit/index file1 &&
	echo second > file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m "second" &&

	shit symbolic-ref HEAD refs/heads/third &&
	rm .shit/index file2 &&
	echo third > file3 &&
	shit add file3 &&
	test_tick &&
	shit commit -m "third"

'

test_expect_success 'cherry-pick a root commit' '

	shit checkout second^0 &&
	shit cherry-pick main &&
	echo first >expect &&
	test_cmp expect file1

'

test_expect_success 'revert a root commit' '

	shit revert main &&
	test_path_is_missing file1

'

test_expect_success 'cherry-pick a root commit with an external strategy' '

	shit cherry-pick --strategy=resolve main &&
	echo first >expect &&
	test_cmp expect file1

'

test_expect_success 'revert a root commit with an external strategy' '

	shit revert --strategy=resolve main &&
	test_path_is_missing file1

'

test_expect_success 'cherry-pick two root commits' '

	echo first >expect.file1 &&
	echo second >expect.file2 &&
	echo third >expect.file3 &&

	shit checkout second^0 &&
	shit cherry-pick main third &&

	test_cmp expect.file1 file1 &&
	test_cmp expect.file2 file2 &&
	test_cmp expect.file3 file3 &&
	shit rev-parse --verify HEAD^^ &&
	test_must_fail shit rev-parse --verify HEAD^^^

'

test_done
