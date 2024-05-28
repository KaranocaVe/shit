#!/bin/sh
#
# Copyright (c) 2005 Johannes Schindelin
#

test_description='Test shit rev-parse with different parent options'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

test_cmp_rev_output () {
	shit rev-parse --verify "$1" >expect &&
	eval "$2" >actual &&
	test_cmp expect actual
}

test_expect_success 'setup' '
	test_commit start &&
	test_commit second &&
	shit checkout --orphan tmp &&
	test_commit start2 &&
	shit checkout main &&
	shit merge -m next --allow-unrelated-histories start2 &&
	test_commit final &&

	mkdir .shit/info &&
	test_seq 40 |
	while read i
	do
		shit checkout --orphan "b$i" &&
		test_tick &&
		shit commit --allow-empty -m "$i" &&
		commit=$(shit rev-parse --verify HEAD) &&
		printf "$commit " >>.shit/info/grafts || return 1
	done
'

test_expect_success 'start is valid' '
	shit rev-parse start | grep "^$OID_REGEX$"
'

test_expect_success 'start^0' '
	test_cmp_rev_output tags/start "shit rev-parse start^0"
'

test_expect_success 'start^1 not valid' '
	test_must_fail shit rev-parse --verify start^1
'

test_expect_success 'second^1 = second^' '
	test_cmp_rev_output second^ "shit rev-parse second^1"
'

test_expect_success 'final^1^1^1' '
	test_cmp_rev_output start "shit rev-parse final^1^1^1"
'

test_expect_success 'final^1^1^1 = final^^^' '
	test_cmp_rev_output final^^^ "shit rev-parse final^1^1^1"
'

test_expect_success 'final^1^2' '
	test_cmp_rev_output start2 "shit rev-parse final^1^2"
'

test_expect_success 'final^1^2 != final^1^1' '
	test $(shit rev-parse final^1^2) != $(shit rev-parse final^1^1)
'

test_expect_success 'final^1^3 not valid' '
	test_must_fail shit rev-parse --verify final^1^3
'

test_expect_success '--verify start2^1' '
	test_must_fail shit rev-parse --verify start2^1
'

test_expect_success '--verify start2^0' '
	shit rev-parse --verify start2^0
'

test_expect_success 'final^1^@ = final^1^1 final^1^2' '
	shit rev-parse final^1^1 final^1^2 >expect &&
	shit rev-parse final^1^@ >actual &&
	test_cmp expect actual
'

test_expect_success 'symbolic final^1^@ = final^1^1 final^1^2' '
	shit rev-parse --symbolic final^1^1 final^1^2 >expect &&
	shit rev-parse --symbolic final^1^@ >actual &&
	test_cmp expect actual
'

test_expect_success 'final^1^! = final^1 ^final^1^1 ^final^1^2' '
	shit rev-parse final^1 ^final^1^1 ^final^1^2 >expect &&
	shit rev-parse final^1^! >actual &&
	test_cmp expect actual
'

test_expect_success 'symbolic final^1^! = final^1 ^final^1^1 ^final^1^2' '
	shit rev-parse --symbolic final^1 ^final^1^1 ^final^1^2 >expect &&
	shit rev-parse --symbolic final^1^! >actual &&
	test_cmp expect actual
'

test_expect_success 'large graft octopus' '
	test_cmp_rev_output b31 "shit rev-parse --verify b1^30"
'

test_expect_success 'repack for next test' '
	shit repack -a -d
'

test_expect_success 'short SHA-1 works' '
	start=$(shit rev-parse --verify start) &&
	test_cmp_rev_output start "shit rev-parse ${start%?}"
'

# rev^- tests; we can use a simpler setup for these

test_expect_success 'setup for rev^- tests' '
	test_commit one &&
	test_commit two &&
	test_commit three &&

	# Merge in a branch for testing rev^-
	shit checkout -b branch &&
	shit checkout HEAD^^ &&
	shit merge -m merge --no-edit --no-ff branch &&
	shit checkout -b merge
'

# The merged branch has 2 commits + the merge
test_expect_success 'rev-list --count merge^- = merge^..merge' '
	shit rev-list --count merge^..merge >expect &&
	echo 3 >actual &&
	test_cmp expect actual
'

# All rev^- rev-parse tests

test_expect_success 'rev-parse merge^- = merge^..merge' '
	shit rev-parse merge^..merge >expect &&
	shit rev-parse merge^- >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse merge^-1 = merge^..merge' '
	shit rev-parse merge^1..merge >expect &&
	shit rev-parse merge^-1 >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse merge^-2 = merge^2..merge' '
	shit rev-parse merge^2..merge >expect &&
	shit rev-parse merge^-2 >actual &&
	test_cmp expect actual
'

test_expect_success 'symbolic merge^-1 = merge^1..merge' '
	shit rev-parse --symbolic merge^1..merge >expect &&
	shit rev-parse --symbolic merge^-1 >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse merge^-0 (invalid parent)' '
	test_must_fail shit rev-parse merge^-0
'

test_expect_success 'rev-parse merge^-3 (invalid parent)' '
	test_must_fail shit rev-parse merge^-3
'

test_expect_success 'rev-parse merge^-^ (garbage after ^-)' '
	test_must_fail shit rev-parse merge^-^
'

test_expect_success 'rev-parse merge^-1x (garbage after ^-1)' '
	test_must_fail shit rev-parse merge^-1x
'

# All rev^- rev-list tests (should be mostly the same as rev-parse; the reason
# for the duplication is that rev-parse and rev-list use different parsers).

test_expect_success 'rev-list merge^- = merge^..merge' '
	shit rev-list merge^..merge >expect &&
	shit rev-list merge^- >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-list merge^-1 = merge^1..merge' '
	shit rev-list merge^1..merge >expect &&
	shit rev-list merge^-1 >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-list merge^-2 = merge^2..merge' '
	shit rev-list merge^2..merge >expect &&
	shit rev-list merge^-2 >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-list merge^-0 (invalid parent)' '
	test_must_fail shit rev-list merge^-0
'

test_expect_success 'rev-list merge^-3 (invalid parent)' '
	test_must_fail shit rev-list merge^-3
'

test_expect_success 'rev-list merge^-^ (garbage after ^-)' '
	test_must_fail shit rev-list merge^-^
'

test_expect_success 'rev-list merge^-1x (garbage after ^-1)' '
	test_must_fail shit rev-list merge^-1x
'

test_expect_success 'rev-parse $garbage^@ does not segfault' '
	test_must_fail shit rev-parse $EMPTY_TREE^@
'

test_expect_success 'rev-parse $garbage...$garbage does not segfault' '
	test_must_fail shit rev-parse $EMPTY_TREE...$EMPTY_BLOB
'

test_done
