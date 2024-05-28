#!/bin/sh

test_description='test multi-tree read-tree without merging'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-read-tree.sh

test_expect_success setup '
	echo one >a &&
	shit add a &&
	shit commit -m initial &&
	shit tag initial &&
	echo two >b &&
	shit add b &&
	shit commit -m second &&
	shit checkout -b side initial &&
	echo three >a &&
	mkdir b &&
	echo four >b/c &&
	shit add b/c &&
	shit commit -m third
'

test_expect_success 'multi-read' '
	read_tree_must_succeed initial main side &&
	test_write_lines a b/c >expect &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_done

