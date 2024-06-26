#!/bin/sh

test_description='shit rebase interactive with rewording'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	test_commit main file-1 test &&

	shit checkout -b stuff &&

	test_commit feature_a file-2 aaa &&
	test_commit feature_b file-2 ddd
'

test_expect_success 'reword without issues functions as intended' '
	test_when_finished "reset_rebase" &&

	shit checkout stuff^0 &&

	set_fake_editor &&
	FAKE_LINES="pick 1 reword 2" FAKE_COMMIT_MESSAGE="feature_b_reworded" \
		shit rebase -i -v main &&

	test "$(shit log -1 --format=%B)" = "feature_b_reworded" &&
	test $(shit rev-list --count HEAD) = 3
'

test_expect_success 'reword after a conflict preserves commit' '
	test_when_finished "reset_rebase" &&

	shit checkout stuff^0 &&

	set_fake_editor &&
	test_must_fail env FAKE_LINES="reword 2" \
		shit rebase -i -v main &&

	shit checkout --theirs file-2 &&
	shit add file-2 &&
	FAKE_COMMIT_MESSAGE="feature_b_reworded" shit rebase --continue &&

	test "$(shit log -1 --format=%B)" = "feature_b_reworded" &&
	test $(shit rev-list --count HEAD) = 2
'

test_done
