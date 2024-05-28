#!/bin/sh

test_description='test read-tree into a fresh index file'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo one >a &&
	shit add a &&
	shit commit -m initial
'

test_expect_success 'non-existent index file' '
	rm -f new-index &&
	shit_INDEX_FILE=new-index shit read-tree main
'

test_expect_success 'empty index file' '
	rm -f new-index &&
	> new-index &&
	shit_INDEX_FILE=new-index shit read-tree main
'

test_done

