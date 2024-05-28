#!/bin/sh

test_description='previous branch syntax @{-n}'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'branch -d @{-1}' '
	test_commit A &&
	shit checkout -b junk &&
	shit checkout - &&
	echo refs/heads/main >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	shit branch -d @{-1} &&
	test_must_fail shit rev-parse --verify refs/heads/junk
'

test_expect_success 'branch -d @{-12} when there is not enough switches yet' '
	shit reflog expire --expire=now &&
	shit checkout -b junk2 &&
	shit checkout - &&
	echo refs/heads/main >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	test_must_fail shit branch -d @{-12} &&
	shit rev-parse --verify refs/heads/main
'

test_expect_success 'merge @{-1}' '
	shit checkout A &&
	test_commit B &&
	shit checkout A &&
	test_commit C &&
	test_commit D &&
	shit branch -f main B &&
	shit branch -f other &&
	shit checkout other &&
	shit checkout main &&
	shit merge @{-1} &&
	shit cat-file commit HEAD | grep "Merge branch '\''other'\''"
'

test_expect_success 'merge @{-1}~1' '
	shit checkout main &&
	shit reset --hard B &&
	shit checkout other &&
	shit checkout main &&
	shit merge @{-1}~1 &&
	shit cat-file commit HEAD >actual &&
	grep "Merge branch '\''other'\''" actual
'

test_expect_success 'merge @{-100} before checking out that many branches yet' '
	shit reflog expire --expire=now &&
	shit checkout -f main &&
	shit reset --hard B &&
	shit branch -f other C &&
	shit checkout other &&
	shit checkout main &&
	test_must_fail shit merge @{-100}
'

test_expect_success 'log -g @{-1}' '
	shit checkout -b last_branch &&
	shit checkout -b new_branch &&
	echo "last_branch@{0}" >expect &&
	shit log -g --format=%gd @{-1} >actual &&
	test_cmp expect actual
'

test_done

