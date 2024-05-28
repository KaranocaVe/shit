#!/bin/sh

test_description='"shit merge" top-level frontend'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

t3033_reset () {
	shit checkout -B main two &&
	shit branch -f left three &&
	shit branch -f right four
}

test_expect_success setup '
	test_commit one &&
	shit branch left &&
	shit branch right &&
	test_commit two &&
	shit checkout left &&
	test_commit three &&
	shit checkout right &&
	test_commit four &&
	shit checkout --orphan newroot &&
	test_commit five &&
	shit checkout main
'

# Local branches

test_expect_success 'merge an octopus into void' '
	t3033_reset &&
	shit checkout --orphan test &&
	shit rm -fr . &&
	test_must_fail shit merge left right &&
	test_must_fail shit rev-parse --verify HEAD &&
	shit diff --quiet &&
	test_must_fail shit rev-parse HEAD
'

test_expect_success 'merge an octopus, fast-forward (ff)' '
	t3033_reset &&
	shit reset --hard one &&
	shit merge left right &&
	# one is ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^3 &&
	shit rev-parse HEAD^1 HEAD^2 | sort >actual &&
	shit rev-parse three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge octopus, non-fast-forward (ff)' '
	t3033_reset &&
	shit reset --hard one &&
	shit merge --no-ff left right &&
	# one is ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse one three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge octopus, fast-forward (does not ff)' '
	t3033_reset &&
	shit merge left right &&
	# two (main) is not an ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse two three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge octopus, non-fast-forward' '
	t3033_reset &&
	shit merge --no-ff left right &&
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse two three four | sort >expect &&
	test_cmp expect actual
'

# The same set with FETCH_HEAD

test_expect_success 'merge FETCH_HEAD octopus into void' '
	t3033_reset &&
	shit checkout --orphan test &&
	shit rm -fr . &&
	shit fetch . left right &&
	test_must_fail shit merge FETCH_HEAD &&
	test_must_fail shit rev-parse --verify HEAD &&
	shit diff --quiet &&
	test_must_fail shit rev-parse HEAD
'

test_expect_success 'merge FETCH_HEAD octopus fast-forward (ff)' '
	t3033_reset &&
	shit reset --hard one &&
	shit fetch . left right &&
	shit merge FETCH_HEAD &&
	# one is ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^3 &&
	shit rev-parse HEAD^1 HEAD^2 | sort >actual &&
	shit rev-parse three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge FETCH_HEAD octopus non-fast-forward (ff)' '
	t3033_reset &&
	shit reset --hard one &&
	shit fetch . left right &&
	shit merge --no-ff FETCH_HEAD &&
	# one is ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse one three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge FETCH_HEAD octopus fast-forward (does not ff)' '
	t3033_reset &&
	shit fetch . left right &&
	shit merge FETCH_HEAD &&
	# two (main) is not an ancestor of three (left) and four (right)
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse two three four | sort >expect &&
	test_cmp expect actual
'

test_expect_success 'merge FETCH_HEAD octopus non-fast-forward' '
	t3033_reset &&
	shit fetch . left right &&
	shit merge --no-ff FETCH_HEAD &&
	test_must_fail shit rev-parse --verify HEAD^4 &&
	shit rev-parse HEAD^1 HEAD^2 HEAD^3 | sort >actual &&
	shit rev-parse two three four | sort >expect &&
	test_cmp expect actual
'

# two-project merge
test_expect_success 'refuse two-project merge by default' '
	t3033_reset &&
	shit reset --hard four &&
	test_must_fail shit merge five
'

test_expect_success 'refuse two-project merge by default, quit before --autostash happens' '
	t3033_reset &&
	shit reset --hard four &&
	echo change >>one.t &&
	shit diff >expect &&
	test_must_fail shit merge --autostash five 2>err &&
	test_grep ! "stash" err &&
	shit diff >actual &&
	test_cmp expect actual
'

test_expect_success 'two-project merge with --allow-unrelated-histories' '
	t3033_reset &&
	shit reset --hard four &&
	shit merge --allow-unrelated-histories five &&
	shit diff --exit-code five
'

test_expect_success 'two-project merge with --allow-unrelated-histories with --autostash' '
	t3033_reset &&
	shit reset --hard four &&
	echo change >>one.t &&
	shit diff one.t >expect &&
	shit merge --allow-unrelated-histories --autostash five 2>err &&
	test_grep "Applied autostash." err &&
	shit diff one.t >actual &&
	test_cmp expect actual
'

test_done
