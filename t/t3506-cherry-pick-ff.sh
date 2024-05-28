#!/bin/sh

test_description='test cherry-picking with --ff option'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo first > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m "first" &&
	shit tag first &&

	shit checkout -b other &&
	echo second >> file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m "second" &&
	shit tag second &&
	test_oid_cache <<-EOF
	cp_ff sha1:1df192cd8bc58a2b275d842cede4d221ad9000d1
	cp_ff sha256:e70d6b7fc064bddb516b8d512c9057094b96ce6ff08e12080acc4fe7f1d60a1d
	EOF
'

test_expect_success 'cherry-pick using --ff fast forwards' '
	shit checkout main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick --ff second &&
	test "$(shit rev-parse --verify HEAD)" = "$(shit rev-parse --verify second)"
'

test_expect_success 'cherry-pick not using --ff does not fast forwards' '
	shit checkout main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick second &&
	test "$(shit rev-parse --verify HEAD)" != "$(shit rev-parse --verify second)"
'

#
# We setup the following graph:
#
#	      B---C
#	     /   /
#	first---A
#
# (This has been taken from t3502-cherry-pick-merge.sh)
#
test_expect_success 'merge setup' '
	shit checkout main &&
	shit reset --hard first &&
	echo new line >A &&
	shit add A &&
	test_tick &&
	shit commit -m "add line to A" A &&
	shit tag A &&
	shit checkout -b side first &&
	echo new line >B &&
	shit add B &&
	test_tick &&
	shit commit -m "add line to B" B &&
	shit tag B &&
	shit checkout main &&
	shit merge side &&
	shit tag C &&
	shit checkout -b new A
'

test_expect_success 'cherry-pick explicit first parent of a non-merge with --ff' '
	shit reset --hard A -- &&
	shit cherry-pick --ff -m 1 B &&
	shit diff --exit-code C --
'

test_expect_success 'cherry pick a merge with --ff but without -m should fail' '
	shit reset --hard A -- &&
	test_must_fail shit cherry-pick --ff C &&
	shit diff --exit-code A --
'

test_expect_success 'cherry pick with --ff a merge (1)' '
	shit reset --hard A -- &&
	shit cherry-pick --ff -m 1 C &&
	shit diff --exit-code C &&
	test "$(shit rev-parse --verify HEAD)" = "$(shit rev-parse --verify C)"
'

test_expect_success 'cherry pick with --ff a merge (2)' '
	shit reset --hard B -- &&
	shit cherry-pick --ff -m 2 C &&
	shit diff --exit-code C &&
	test "$(shit rev-parse --verify HEAD)" = "$(shit rev-parse --verify C)"
'

test_expect_success 'cherry pick a merge relative to nonexistent parent with --ff should fail' '
	shit reset --hard B -- &&
	test_must_fail shit cherry-pick --ff -m 3 C
'

test_expect_success 'cherry pick a root commit with --ff' '
	shit reset --hard first -- &&
	shit rm file1 &&
	echo first >file2 &&
	shit add file2 &&
	shit commit --amend -m "file2" &&
	shit cherry-pick --ff first &&
	test "$(shit rev-parse --verify HEAD)" = "$(test_oid cp_ff)"
'

test_expect_success 'cherry-pick --ff on unborn branch' '
	shit checkout --orphan unborn &&
	shit rm --cached -r . &&
	rm -rf * &&
	shit cherry-pick --ff first &&
	test_cmp_rev first HEAD
'

test_done
