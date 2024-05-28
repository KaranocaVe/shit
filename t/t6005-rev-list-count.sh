#!/bin/sh

test_description='shit rev-list --max-count and --skip test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
    for n in 1 2 3 4 5 ; do
	echo $n > a &&
	shit add a &&
	shit commit -m "$n" || return 1
    done
'

test_expect_success 'no options' '
	test_stdout_line_count = 5 shit rev-list HEAD
'

test_expect_success '--max-count' '
	test_must_fail shit rev-list --max-count=1q HEAD 2>error &&
	grep "not an integer" error &&

	test_stdout_line_count = 0 shit rev-list HEAD --max-count=0 &&
	test_stdout_line_count = 3 shit rev-list HEAD --max-count=3 &&
	test_stdout_line_count = 5 shit rev-list HEAD --max-count=5 &&
	test_stdout_line_count = 5 shit rev-list HEAD --max-count=10 &&
	test_stdout_line_count = 5 shit rev-list HEAD --max-count=-1
'

test_expect_success '--max-count all forms' '
	test_must_fail shit rev-list -1q HEAD 2>error &&
	grep "not an integer" error &&
	test_must_fail shit rev-list --1 HEAD &&
	test_must_fail shit rev-list -n 1q HEAD 2>error &&
	grep "not an integer" error &&

	test_stdout_line_count = 1 shit rev-list HEAD --max-count=1 &&
	test_stdout_line_count = 1 shit rev-list HEAD -1 &&
	test_stdout_line_count = 1 shit rev-list HEAD -n1 &&
	test_stdout_line_count = 1 shit rev-list HEAD -n 1 &&
	test_stdout_line_count = 5 shit rev-list HEAD -n -1
'

test_expect_success '--skip' '
	test_must_fail shit rev-list --skip 1q HEAD 2>error &&
	grep "not an integer" error &&

	test_stdout_line_count = 5 shit rev-list HEAD --skip=0 &&
	test_stdout_line_count = 2 shit rev-list HEAD --skip=3 &&
	test_stdout_line_count = 0 shit rev-list HEAD --skip=5 &&
	test_stdout_line_count = 0 shit rev-list HEAD --skip=10
'

test_expect_success '--skip --max-count' '
	test_stdout_line_count = 0 shit rev-list HEAD --skip=0 --max-count=0 &&
	test_stdout_line_count = 5 shit rev-list HEAD --skip=0 --max-count=10 &&
	test_stdout_line_count = 0 shit rev-list HEAD --skip=3 --max-count=0 &&
	test_stdout_line_count = 1 shit rev-list HEAD --skip=3 --max-count=1 &&
	test_stdout_line_count = 2 shit rev-list HEAD --skip=3 --max-count=2 &&
	test_stdout_line_count = 2 shit rev-list HEAD --skip=3 --max-count=10 &&
	test_stdout_line_count = 0 shit rev-list HEAD --skip=5 --max-count=10 &&
	test_stdout_line_count = 0 shit rev-list HEAD --skip=10 --max-count=10
'

test_done
