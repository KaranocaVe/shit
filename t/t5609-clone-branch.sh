#!/bin/sh

test_description='clone --branch option'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_HEAD() {
	echo refs/heads/"$1" >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual
}

check_file() {
	echo "$1" >expect &&
	test_cmp expect file
}

test_expect_success 'setup' '
	mkdir parent &&
	(cd parent && shit init &&
	 echo one >file && shit add file && shit commit -m one &&
	 shit checkout -b two &&
	 echo two >file && shit add file && shit commit -m two &&
	 shit checkout main) &&
	mkdir empty &&
	(cd empty && shit init)
'

test_expect_success 'vanilla clone chooses HEAD' '
	shit clone parent clone &&
	(cd clone &&
	 check_HEAD main &&
	 check_file one
	)
'

test_expect_success 'clone -b chooses specified branch' '
	shit clone -b two parent clone-two &&
	(cd clone-two &&
	 check_HEAD two &&
	 check_file two
	)
'

test_expect_success 'clone -b sets up tracking' '
	(cd clone-two &&
	 echo origin >expect &&
	 shit config branch.two.remote >actual &&
	 echo refs/heads/two >>expect &&
	 shit config branch.two.merge >>actual &&
	 test_cmp expect actual
	)
'

test_expect_success 'clone -b does not munge remotes/origin/HEAD' '
	(cd clone-two &&
	 echo refs/remotes/origin/main >expect &&
	 shit symbolic-ref refs/remotes/origin/HEAD >actual &&
	 test_cmp expect actual
	)
'

test_expect_success 'clone -b with bogus branch' '
	test_must_fail shit clone -b bogus parent clone-bogus
'

test_expect_success 'clone -b not allowed with empty repos' '
	test_must_fail shit clone -b branch empty clone-branch-empty
'

test_done
