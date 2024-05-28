#!/bin/sh

test_description='shit rebase interactive environment'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit one &&
	test_commit two &&
	test_commit three
'

test_expect_success 'rebase --exec does not muck with shit_DIR' '
	shit rebase --exec "printf %s \$shit_DIR >environ" HEAD~1 &&
	test_must_be_empty environ
'

test_expect_success 'rebase --exec does not muck with shit_WORK_TREE' '
	shit rebase --exec "printf %s \$shit_WORK_TREE >environ" HEAD~1 &&
	test_must_be_empty environ
'

test_done
