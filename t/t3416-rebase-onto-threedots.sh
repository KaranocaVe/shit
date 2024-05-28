#!/bin/sh

test_description='shit rebase --onto A...B'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-rebase.sh"

# Rebase only the tip commit of "topic" on merge base between "main"
# and "topic".  Cannot do this for "side" with "main" because there
# is no single merge base.
#
#
#	    F---G topic                             G'
#	   /                                       /
# A---B---C---D---E main        -->       A---B---C---D---E
#      \   \ /
#	\   x
#	 \ / \
#	  H---I---J---K side

test_expect_success setup '
	test_commit A &&
	test_commit B &&
	shit branch side &&
	test_commit C &&
	shit branch topic &&
	shit checkout side &&
	test_commit H &&
	shit checkout main &&
	test_tick &&
	shit merge H &&
	shit tag D &&
	test_commit E &&
	shit checkout topic &&
	test_commit F &&
	test_commit G &&
	shit checkout side &&
	test_tick &&
	shit merge C &&
	shit tag I &&
	test_commit J &&
	test_commit K
'

test_expect_success 'rebase --onto main...topic' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&

	shit rebase --onto main...topic F &&
	shit rev-parse HEAD^1 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --onto main...' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&

	shit rebase --onto main... F &&
	shit rev-parse HEAD^1 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --onto main...side' '
	shit reset --hard &&
	shit checkout side &&
	shit reset --hard K &&

	test_must_fail shit rebase --onto main...side J
'

test_expect_success 'rebase -i --onto main...topic' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&
	(
		set_fake_editor &&
		EXPECT_COUNT=1 shit rebase -i --onto main...topic F
	) &&
	shit rev-parse HEAD^1 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase -i --onto main...' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&
	(
		set_fake_editor &&
		EXPECT_COUNT=1 shit rebase -i --onto main... F
	) &&
	shit rev-parse HEAD^1 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --onto main...side requires a single merge-base' '
	shit reset --hard &&
	shit checkout side &&
	shit reset --hard K &&

	test_must_fail shit rebase -i --onto main...side J 2>err &&
	grep "need exactly one merge base" err
'

test_expect_success 'rebase --keep-base --onto incompatible' '
	test_must_fail shit rebase --keep-base --onto main...
'

test_expect_success 'rebase --keep-base --root incompatible' '
	test_must_fail shit rebase --keep-base --root
'

test_expect_success 'rebase --keep-base main from topic' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&

	shit rebase --keep-base main &&
	shit rev-parse C >base.expect &&
	shit merge-base main HEAD >base.actual &&
	test_cmp base.expect base.actual &&

	shit rev-parse HEAD~2 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --keep-base main topic from main' '
	shit checkout main &&
	shit branch -f topic G &&

	shit rebase --keep-base main topic &&
	shit rev-parse C >base.expect &&
	shit merge-base main HEAD >base.actual &&
	test_cmp base.expect base.actual &&

	shit rev-parse HEAD~2 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --keep-base main from side' '
	shit reset --hard &&
	shit checkout side &&
	shit reset --hard K &&

	test_must_fail shit rebase --keep-base main
'

test_expect_success 'rebase -i --keep-base main from topic' '
	shit reset --hard &&
	shit checkout topic &&
	shit reset --hard G &&

	(
		set_fake_editor &&
		EXPECT_COUNT=2 shit rebase -i --keep-base main
	) &&
	shit rev-parse C >base.expect &&
	shit merge-base main HEAD >base.actual &&
	test_cmp base.expect base.actual &&

	shit rev-parse HEAD~2 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase -i --keep-base main topic from main' '
	shit checkout main &&
	shit branch -f topic G &&

	(
		set_fake_editor &&
		EXPECT_COUNT=2 shit rebase -i --keep-base main topic
	) &&
	shit rev-parse C >base.expect &&
	shit merge-base main HEAD >base.actual &&
	test_cmp base.expect base.actual &&

	shit rev-parse HEAD~2 >actual &&
	shit rev-parse C^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'rebase --keep-base requires a single merge base' '
	shit reset --hard &&
	shit checkout side &&
	shit reset --hard K &&

	test_must_fail shit rebase -i --keep-base main 2>err &&
	grep "need exactly one merge base with branch" err
'

test_expect_success 'rebase --keep-base keeps cherry picks' '
	shit checkout -f -B main E &&
	shit cherry-pick F &&
	(
		set_fake_editor &&
		EXPECT_COUNT=2 shit rebase -i --keep-base HEAD G
	) &&
	test_cmp_rev HEAD G
'

test_expect_success 'rebase --keep-base --no-reapply-cherry-picks' '
	shit checkout -f -B main E &&
	shit cherry-pick F &&
	(
		set_fake_editor &&
		EXPECT_COUNT=1 shit rebase -i --keep-base \
					--no-reapply-cherry-picks HEAD G
	) &&
	test_cmp_rev HEAD^ C
'

# This must be the last test in this file
test_expect_success '$EDITOR and friends are unchanged' '
	test_editor_unchanged
'

test_done
