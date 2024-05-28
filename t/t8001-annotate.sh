#!/bin/sh

test_description='shit annotate'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

PROG='shit annotate'
. "$TEST_DIRECTORY"/annotate-tests.sh

test_expect_success 'annotate old revision' '
	shit annotate file main >actual &&
	awk "{ print \$3; }" <actual >authors &&
	test 2 = $(grep A <authors | wc -l) &&
	test 2 = $(grep B <authors | wc -l)
'

test_done
