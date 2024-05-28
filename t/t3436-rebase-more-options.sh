#!/bin/sh
#
# Copyright (c) 2019 Rohit Ashiwal
#

test_description='tests to ensure compatibility between am and interactive backends'

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

shit_AUTHOR_DATE="1999-04-02T08:03:20+05:30"
export shit_AUTHOR_DATE

# This is a special case in which both am and interactive backends
# provide the same output. It was done intentionally because
# both the backends fall short of optimal behaviour.
test_expect_success 'setup' '
	shit checkout -b topic &&
	test_write_lines "line 1" "	line 2" "line 3" >file &&
	shit add file &&
	shit commit -m "add file" &&

	test_write_lines "line 1" "new line 2" "line 3" >file &&
	shit commit -am "update file" &&
	shit tag side &&
	test_commit commit1 foo foo1 &&
	test_commit commit2 foo foo2 &&
	test_commit commit3 foo foo3 &&

	shit checkout --orphan main &&
	rm foo &&
	test_write_lines "line 1" "        line 2" "line 3" >file &&
	shit commit -am "add file" &&
	shit tag main &&

	mkdir test-bin &&
	write_script test-bin/shit-merge-test <<-\EOF
	exec shit merge-recursive "$@"
	EOF
'

test_expect_success '--ignore-whitespace works with apply backend' '
	test_must_fail shit rebase --apply main side &&
	shit rebase --abort &&
	shit rebase --apply --ignore-whitespace main side &&
	shit diff --exit-code side
'

test_expect_success '--ignore-whitespace works with merge backend' '
	test_must_fail shit rebase --merge main side &&
	shit rebase --abort &&
	shit rebase --merge --ignore-whitespace main side &&
	shit diff --exit-code side
'

test_expect_success '--ignore-whitespace is remembered when continuing' '
	(
		set_fake_editor &&
		FAKE_LINES="break 1" shit rebase -i --ignore-whitespace \
			main side &&
		shit rebase --continue
	) &&
	shit diff --exit-code side
'

test_ctime_is_atime () {
	shit log $1 --format="$shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> %ai" >authortime &&
	shit log $1 --format="%cn <%ce> %ci" >committertime &&
	test_cmp authortime committertime
}

test_expect_success '--committer-date-is-author-date works with apply backend' '
	shit_AUTHOR_DATE="@1234 +0300" shit commit --amend --reset-author &&
	shit rebase --apply --committer-date-is-author-date HEAD^ &&
	test_ctime_is_atime -1
'

test_expect_success '--committer-date-is-author-date works with merge backend' '
	shit_AUTHOR_DATE="@1234 +0300" shit commit --amend --reset-author &&
	shit rebase -m --committer-date-is-author-date HEAD^ &&
	test_ctime_is_atime -1
'

test_expect_success '--committer-date-is-author-date works when rewording' '
	shit_AUTHOR_DATE="@1234 +0300" shit commit --amend --reset-author &&
	(
		set_fake_editor &&
		FAKE_COMMIT_MESSAGE=edited \
			FAKE_LINES="reword 1" \
			shit rebase -i --committer-date-is-author-date HEAD^
	) &&
	test_write_lines edited "" >expect &&
	shit log --format="%B" -1 >actual &&
	test_cmp expect actual &&
	test_ctime_is_atime -1
'

test_expect_success '--committer-date-is-author-date works with rebase -r' '
	shit checkout side &&
	shit_AUTHOR_DATE="@1234 +0300" shit merge --no-ff commit3 &&
	shit rebase -r --root --committer-date-is-author-date &&
	test_ctime_is_atime
'

test_expect_success '--committer-date-is-author-date works when forking merge' '
	shit checkout side &&
	shit_AUTHOR_DATE="@1234 +0300" shit merge --no-ff commit3 &&
	PATH="./test-bin:$PATH" shit rebase -r --root --strategy=test \
					--committer-date-is-author-date &&
	test_ctime_is_atime
'

test_expect_success '--committer-date-is-author-date works when committing conflict resolution' '
	shit checkout commit2 &&
	shit_AUTHOR_DATE="@1980 +0000" shit commit --amend --only --reset-author &&
	test_must_fail shit rebase -m --committer-date-is-author-date \
		--onto HEAD^^ HEAD^ &&
	echo resolved > foo &&
	shit add foo &&
	shit rebase --continue &&
	test_ctime_is_atime -1
'

# Checking for +0000 in the author date is sufficient since the
# default timezone is UTC but the timezone used while committing is
# +0530. The inverted logic in the grep is necessary to check all the
# author dates in the file.
test_atime_is_ignored () {
	shit log $1 --format=%ai >authortime &&
	! grep -v +0000 authortime
}

test_expect_success '--reset-author-date works with apply backend' '
	shit commit --amend --date="$shit_AUTHOR_DATE" &&
	shit rebase --apply --reset-author-date HEAD^ &&
	test_atime_is_ignored -1
'

test_expect_success '--reset-author-date works with merge backend' '
	shit commit --amend --date="$shit_AUTHOR_DATE" &&
	shit rebase --reset-author-date -m HEAD^ &&
	test_atime_is_ignored -1
'

test_expect_success '--reset-author-date works after conflict resolution' '
	test_must_fail shit rebase --reset-author-date -m \
		--onto commit2^^ commit2^ commit2 &&
	echo resolved >foo &&
	shit add foo &&
	shit rebase --continue &&
	test_atime_is_ignored -1
'

test_expect_success '--reset-author-date works with rebase -r' '
	shit checkout side &&
	shit merge --no-ff commit3 &&
	shit rebase -r --root --reset-author-date &&
	test_atime_is_ignored
'

test_expect_success '--reset-author-date with --committer-date-is-author-date works' '
	test_must_fail shit rebase -m --committer-date-is-author-date \
		--reset-author-date --onto commit2^^ commit2^ commit3 &&
	shit checkout --theirs foo &&
	shit add foo &&
	shit rebase --continue &&
	test_ctime_is_atime -2 &&
	test_atime_is_ignored -2
'

test_expect_success 'reset-author-date with --committer-date-is-author-date works when rewording' '
	shit_AUTHOR_DATE="@1234 +0300" shit commit --amend --reset-author &&
	(
		set_fake_editor &&
		FAKE_COMMIT_MESSAGE=edited \
			FAKE_LINES="reword 1" \
			shit rebase -i --committer-date-is-author-date \
				--reset-author-date HEAD^
	) &&
	test_write_lines edited "" >expect &&
	shit log --format="%B" -1 >actual &&
	test_cmp expect actual &&
	test_atime_is_ignored -1
'

test_expect_success '--reset-author-date --committer-date-is-author-date works when forking merge' '
	shit_SEQUENCE_EDITOR="echo \"merge -C $(shit rev-parse HEAD) commit3\">" \
		PATH="./test-bin:$PATH" shit rebase -i --strategy=test \
				--reset-author-date \
				--committer-date-is-author-date side side &&
	test_ctime_is_atime -1 &&
	test_atime_is_ignored -1
 '

test_expect_success '--ignore-date is an alias for --reset-author-date' '
	shit commit --amend --date="$shit_AUTHOR_DATE" &&
	shit rebase --apply --ignore-date HEAD^ &&
	shit commit --allow-empty -m empty --date="$shit_AUTHOR_DATE" &&
	shit rebase -m --ignore-date HEAD^ &&
	test_atime_is_ignored -2
'

# This must be the last test in this file
test_expect_success '$EDITOR and friends are unchanged' '
	test_editor_unchanged
'

test_done
