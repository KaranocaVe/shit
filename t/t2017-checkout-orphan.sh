#!/bin/sh
#
# Copyright (c) 2010 Erick Mattos
#

test_description='shit checkout --orphan

Main Tests for --orphan functionality.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

TEST_FILE=foo

test_expect_success 'Setup' '
	echo "Initial" >"$TEST_FILE" &&
	shit add "$TEST_FILE" &&
	shit commit -m "First Commit" &&
	test_tick &&
	echo "State 1" >>"$TEST_FILE" &&
	shit add "$TEST_FILE" &&
	test_tick &&
	shit commit -m "Second Commit"
'

test_expect_success '--orphan creates a new orphan branch from HEAD' '
	shit checkout --orphan alpha &&
	test_must_fail shit rev-parse --verify HEAD &&
	test "refs/heads/alpha" = "$(shit symbolic-ref HEAD)" &&
	test_tick &&
	shit commit -m "Third Commit" &&
	test_must_fail shit rev-parse --verify HEAD^ &&
	shit diff-tree --quiet main alpha
'

test_expect_success '--orphan creates a new orphan branch from <start_point>' '
	shit checkout main &&
	shit checkout --orphan beta main^ &&
	test_must_fail shit rev-parse --verify HEAD &&
	test "refs/heads/beta" = "$(shit symbolic-ref HEAD)" &&
	test_tick &&
	shit commit -m "Fourth Commit" &&
	test_must_fail shit rev-parse --verify HEAD^ &&
	shit diff-tree --quiet main^ beta
'

test_expect_success '--orphan must be rejected with -b' '
	shit checkout main &&
	test_must_fail shit checkout --orphan new -b newer &&
	test refs/heads/main = "$(shit symbolic-ref HEAD)"
'

test_expect_success '--orphan must be rejected with -t' '
	shit checkout main &&
	test_must_fail shit checkout --orphan new -t main &&
	test refs/heads/main = "$(shit symbolic-ref HEAD)"
'

test_expect_success '--orphan ignores branch.autosetupmerge' '
	shit checkout main &&
	shit config branch.autosetupmerge always &&
	shit checkout --orphan gamma &&
	test_cmp_config "" --default "" branch.gamma.merge &&
	test refs/heads/gamma = "$(shit symbolic-ref HEAD)" &&
	test_must_fail shit rev-parse --verify HEAD^ &&
	shit checkout main &&
	shit config branch.autosetupmerge inherit &&
	shit checkout --orphan eta &&
	test_cmp_config "" --default "" branch.eta.merge &&
	test_cmp_config "" --default "" branch.eta.remote &&
	echo refs/heads/eta >expected &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expected actual &&
	test_must_fail shit rev-parse --verify HEAD^
'

test_expect_success '--orphan makes reflog by default' '
	shit checkout main &&
	shit config --unset core.logAllRefUpdates &&
	shit checkout --orphan delta &&
	test_must_fail shit rev-parse --verify delta@{0} &&
	shit commit -m Delta &&
	shit rev-parse --verify delta@{0}
'

test_expect_success '--orphan does not make reflog when core.logAllRefUpdates = false' '
	shit checkout main &&
	shit config core.logAllRefUpdates false &&
	shit checkout --orphan epsilon &&
	test_must_fail shit rev-parse --verify epsilon@{0} &&
	shit commit -m Epsilon &&
	test_must_fail shit rev-parse --verify epsilon@{0}
'

test_expect_success '--orphan with -l makes reflog when core.logAllRefUpdates = false' '
	shit checkout main &&
	shit checkout -l --orphan zeta &&
	test_must_fail shit rev-parse --verify zeta@{0} &&
	shit commit -m Zeta &&
	shit rev-parse --verify zeta@{0}
'

test_expect_success 'giving up --orphan not committed when -l and core.logAllRefUpdates = false deletes reflog' '
	shit checkout main &&
	shit checkout -l --orphan eta &&
	test_must_fail shit rev-parse --verify eta@{0} &&
	shit checkout main &&
	test_must_fail shit rev-parse --verify eta@{0}
'

test_expect_success '--orphan is rejected with an existing name' '
	shit checkout main &&
	test_must_fail shit checkout --orphan main &&
	test refs/heads/main = "$(shit symbolic-ref HEAD)"
'

test_expect_success '--orphan refuses to switch if a merge is needed' '
	shit checkout main &&
	shit reset --hard &&
	echo local >>"$TEST_FILE" &&
	cat "$TEST_FILE" >"$TEST_FILE.saved" &&
	test_must_fail shit checkout --orphan new main^ &&
	test refs/heads/main = "$(shit symbolic-ref HEAD)" &&
	test_cmp "$TEST_FILE" "$TEST_FILE.saved" &&
	shit diff-index --quiet --cached HEAD &&
	shit reset --hard
'

test_expect_success 'cannot --detach on an unborn branch' '
	shit checkout main &&
	shit checkout --orphan new &&
	test_must_fail shit checkout --detach
'

test_done
