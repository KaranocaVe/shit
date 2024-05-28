#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
#

test_description='shit rebase --merge --skip tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

# we assume the default shit am -3 --skip strategy is tested independently
# and always works :)

test_expect_success setup '
	echo hello > hello &&
	shit add hello &&
	shit commit -m "hello" &&
	shit branch skip-reference &&
	shit tag hello &&

	echo world >> hello &&
	shit commit -a -m "hello world" &&
	echo goodbye >> hello &&
	shit commit -a -m "goodbye" &&
	shit tag goodbye &&

	shit checkout --detach &&
	shit checkout HEAD^ . &&
	test_tick &&
	shit commit -m reverted-goodbye &&
	shit tag reverted-goodbye &&
	shit checkout goodbye &&
	test_tick &&
	shit_AUTHOR_NAME="Another Author" \
		shit_AUTHOR_EMAIL="another.author@example.com" \
		shit commit --amend --no-edit -m amended-goodbye \
			--reset-author &&
	test_tick &&
	shit tag amended-goodbye &&

	shit checkout -f skip-reference &&
	echo moo > hello &&
	shit commit -a -m "we should skip this" &&
	echo moo > cow &&
	shit add cow &&
	shit commit -m "this should not be skipped" &&
	shit branch pre-rebase skip-reference &&
	shit branch skip-merge skip-reference
	'

test_expect_success 'rebase with shit am -3 (default)' '
	test_must_fail shit rebase --apply main
'

test_expect_success 'rebase --skip can not be used with other options' '
	test_must_fail shit rebase -v --skip &&
	test_must_fail shit rebase --skip -v
'

test_expect_success 'rebase --skip with am -3' '
	shit rebase --skip
	'

test_expect_success 'rebase moves back to skip-reference' '
	test refs/heads/skip-reference = $(shit symbolic-ref HEAD) &&
	shit branch post-rebase &&
	shit reset --hard pre-rebase &&
	test_must_fail shit rebase main &&
	echo "hello" > hello &&
	shit add hello &&
	shit rebase --continue &&
	test refs/heads/skip-reference = $(shit symbolic-ref HEAD) &&
	shit reset --hard post-rebase
'

test_expect_success 'checkout skip-merge' 'shit checkout -f skip-merge'

test_expect_success 'rebase with --merge' '
	test_must_fail shit rebase --merge main
'

test_expect_success 'rebase --skip with --merge' '
	shit rebase --skip
'

test_expect_success 'merge and reference trees equal' '
	test -z "$(shit diff-tree skip-merge skip-reference)"
'

test_expect_success 'moved back to branch correctly' '
	test refs/heads/skip-merge = $(shit symbolic-ref HEAD)
'

test_debug 'shitk --all & sleep 1'

test_expect_success 'skipping final pick removes .shit/MERGE_MSG' '
	test_must_fail shit rebase --onto hello reverted-goodbye^ \
		reverted-goodbye &&
	shit rebase --skip &&
	test_path_is_missing .shit/MERGE_MSG
'

test_expect_success 'correct advice upon picking empty commit' '
	test_when_finished "shit rebase --abort" &&
	test_must_fail shit rebase -i --onto goodbye \
		amended-goodbye^ amended-goodbye 2>err &&
	test_grep "previous cherry-pick is now empty" err &&
	test_grep "shit rebase --skip" err &&
	test_must_fail shit commit &&
	test_grep "shit rebase --skip" err
'

test_expect_success 'correct authorship when committing empty pick' '
	test_when_finished "shit rebase --abort" &&
	test_must_fail shit rebase -i --onto goodbye \
		amended-goodbye^ amended-goodbye &&
	shit commit --allow-empty &&
	shit log --pretty=format:"%an <%ae>%n%ad%B" -1 amended-goodbye >expect &&
	shit log --pretty=format:"%an <%ae>%n%ad%B" -1 HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'correct advice upon rewording empty commit' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="reword 1" shit rebase -i \
			--onto goodbye amended-goodbye^ amended-goodbye 2>err
	) &&
	test_grep "previous cherry-pick is now empty" err &&
	test_grep "shit rebase --skip" err &&
	test_must_fail shit commit &&
	test_grep "shit rebase --skip" err
'

test_expect_success 'correct advice upon editing empty commit' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="edit 1" shit rebase -i \
			--onto goodbye amended-goodbye^ amended-goodbye 2>err
	) &&
	test_grep "previous cherry-pick is now empty" err &&
	test_grep "shit rebase --skip" err &&
	test_must_fail shit commit &&
	test_grep "shit rebase --skip" err
'

test_expect_success 'correct advice upon cherry-picking an empty commit during a rebase' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 exec_shit_cherry-pick_amended-goodbye" \
			shit rebase -i goodbye^ goodbye 2>err
	) &&
	test_grep "previous cherry-pick is now empty" err &&
	test_grep "shit cherry-pick --skip" err &&
	test_must_fail shit commit 2>err &&
	test_grep "shit cherry-pick --skip" err
'

test_expect_success 'correct advice upon multi cherry-pick picking an empty commit during a rebase' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 exec_shit_cherry-pick_goodbye_amended-goodbye" \
			shit rebase -i goodbye^^ goodbye 2>err
	) &&
	test_grep "previous cherry-pick is now empty" err &&
	test_grep "shit cherry-pick --skip" err &&
	test_must_fail shit commit 2>err &&
	test_grep "shit cherry-pick --skip" err
'

test_expect_success 'fixup that empties commit fails' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 fixup 2" shit rebase -i \
			goodbye^ reverted-goodbye
	)
'

test_expect_success 'squash that empties commit fails' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 squash 2" shit rebase -i \
			goodbye^ reverted-goodbye
	)
'

# Must be the last test in this file
test_expect_success '$EDITOR and friends are unchanged' '
	test_editor_unchanged
'

test_done
