#!/bin/sh

test_description='checkout can switch to last branch and merge base'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial world hello &&
	shit branch other &&
	test_commit --append second world "hello again"
'

test_expect_success '"checkout -" does not work initially' '
	test_must_fail shit checkout -
'

test_expect_success 'first branch switch' '
	shit checkout other
'

test_cmp_symbolic_HEAD_ref () {
	echo refs/heads/"$1" >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual
}

test_expect_success '"checkout -" switches back' '
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref main
'

test_expect_success '"checkout -" switches forth' '
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref other
'

test_expect_success 'detach HEAD' '
	shit checkout $(shit rev-parse HEAD)
'

test_expect_success '"checkout -" attaches again' '
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref other
'

test_expect_success '"checkout -" detaches again' '
	shit checkout - &&

	shit rev-parse other >expect &&
	shit rev-parse HEAD >actual &&
	test_cmp expect actual &&

	test_must_fail shit symbolic-ref HEAD
'

test_expect_success 'more switches' '
	for i in 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1
	do
		shit checkout -b branch$i || return 1
	done
'

more_switches () {
	for i in 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1
	do
		shit checkout branch$i || return 1
	done
}

test_expect_success 'switch to the last' '
	more_switches &&
	shit checkout @{-1} &&
	test_cmp_symbolic_HEAD_ref branch2
'

test_expect_success 'switch to second from the last' '
	more_switches &&
	shit checkout @{-2} &&
	test_cmp_symbolic_HEAD_ref branch3
'

test_expect_success 'switch to third from the last' '
	more_switches &&
	shit checkout @{-3} &&
	test_cmp_symbolic_HEAD_ref branch4
'

test_expect_success 'switch to fourth from the last' '
	more_switches &&
	shit checkout @{-4} &&
	test_cmp_symbolic_HEAD_ref branch5
'

test_expect_success 'switch to twelfth from the last' '
	more_switches &&
	shit checkout @{-12} &&
	test_cmp_symbolic_HEAD_ref branch13
'

test_expect_success 'merge base test setup' '
	shit checkout -b another other &&
	test_commit --append third world "hello again"
'

test_expect_success 'another...main' '
	shit checkout another &&
	shit checkout another...main &&

	shit rev-parse --verify main^ >expect &&
	shit rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '...main' '
	shit checkout another &&
	shit checkout ...main &&

	shit rev-parse --verify main^ >expect &&
	shit rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'main...' '
	shit checkout another &&
	shit checkout main... &&

	shit rev-parse --verify main^ >expect &&
	shit rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '"checkout -" works after a rebase A' '
	shit checkout main &&
	shit checkout other &&
	shit rebase main &&
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref main
'

test_expect_success '"checkout -" works after a rebase A B' '
	shit branch moodle main~1 &&
	shit checkout main &&
	shit checkout other &&
	shit rebase main moodle &&
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref main
'

test_expect_success '"checkout -" works after a rebase -i A' '
	shit checkout main &&
	shit checkout other &&
	shit rebase -i main &&
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref main
'

test_expect_success '"checkout -" works after a rebase -i A B' '
	shit branch foodle main~1 &&
	shit checkout main &&
	shit checkout other &&
	shit rebase main foodle &&
	shit checkout - &&
	test_cmp_symbolic_HEAD_ref main
'

test_done
