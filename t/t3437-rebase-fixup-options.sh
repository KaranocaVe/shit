#!/bin/sh
#
# Copyright (c) 2018 Phillip Wood
#

test_description='shit rebase interactive fixup options

This test checks the "fixup [-C|-c]" command of rebase interactive.
In addition to amending the contents of the commit, "fixup -C"
replaces the original commit message with the message of the fixup
commit. "fixup -c" also replaces the original message, but opens the
editor to allow the user to edit the message before committing. Similar
to the "fixup" command that works with "fixup!", "fixup -C" works with
"amend!" upon --autosquash.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

EMPTY=""

get_author () {
	rev="$1" &&
	shit log -1 --pretty=format:"%an %ae %at" "$rev"
}

test_expect_success 'setup' '
	cat >message <<-EOF &&
	amend! B
	$EMPTY
	new subject
	$EMPTY
	new
	body
	EOF

	test_commit initial &&
	test_commit A A &&
	test_commit B B &&
	get_author HEAD >expected-author &&
	ORIG_AUTHOR_NAME="$shit_AUTHOR_NAME" &&
	ORIG_AUTHOR_EMAIL="$shit_AUTHOR_EMAIL" &&
	shit_AUTHOR_NAME="Amend Author" &&
	shit_AUTHOR_EMAIL="amend@example.com" &&
	test_commit "$(cat message)" A A1 A1 &&
	test_commit A2 A &&
	test_commit A3 A &&
	shit_AUTHOR_NAME="$ORIG_AUTHOR_NAME" &&
	shit_AUTHOR_EMAIL="$ORIG_AUTHOR_EMAIL" &&
	shit checkout -b conflicts-branch A &&
	test_commit conflicts A &&

	set_fake_editor &&
	shit checkout -b branch B &&
	echo B1 >B &&
	test_tick &&
	shit commit --fixup=HEAD -a &&
	shit tag B1 &&
	test_tick &&
	FAKE_COMMIT_AMEND="edited 1" shit commit --fixup=reword:B &&
	test_tick &&
	FAKE_COMMIT_AMEND="edited 2" shit commit --fixup=reword:HEAD &&
	echo B2 >B &&
	test_tick &&
	FAKE_COMMIT_AMEND="edited squash" shit commit --squash=HEAD -a &&
	shit tag B2 &&
	echo B3 >B &&
	test_tick &&
	FAKE_COMMIT_AMEND="edited 3" shit commit -a --fixup=amend:HEAD^ &&
	shit tag B3 &&

	shit_AUTHOR_NAME="Rebase Author" &&
	shit_AUTHOR_EMAIL="rebase.author@example.com" &&
	shit_COMMITTER_NAME="Rebase Committer" &&
	shit_COMMITTER_EMAIL="rebase.committer@example.com"
'

test_expect_success 'simple fixup -C works' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A2 &&
	FAKE_LINES="1 fixup_-C 2" shit rebase -i B &&
	test_cmp_rev HEAD^ B &&
	test_cmp_rev HEAD^{tree} A2^{tree} &&
	test_commit_message HEAD -m "A2"
'

test_expect_success 'simple fixup -c works' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A2 &&
	shit log -1 --pretty=format:%B >expected-fixup-message &&
	test_write_lines "" "Modified A2" >>expected-fixup-message &&
	FAKE_LINES="1 fixup_-c 2" \
		FAKE_COMMIT_AMEND="Modified A2" \
		shit rebase -i B &&
	test_cmp_rev HEAD^ B &&
	test_cmp_rev HEAD^{tree} A2^{tree} &&
	test_commit_message HEAD expected-fixup-message
'

test_expect_success 'fixup -C removes amend! from message' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A1 &&
	shit log -1 --pretty=format:%b >expected-message &&
	FAKE_LINES="1 fixup_-C 2" shit rebase -i A &&
	test_cmp_rev HEAD^ A &&
	test_cmp_rev HEAD^{tree} A1^{tree} &&
	test_commit_message HEAD expected-message &&
	get_author HEAD >actual-author &&
	test_cmp expected-author actual-author
'

test_expect_success 'fixup -C with conflicts gives correct message' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A1 &&
	shit log -1 --pretty=format:%b >expected-message &&
	test_write_lines "" "edited" >>expected-message &&
	test_must_fail env FAKE_LINES="1 fixup_-C 2" shit rebase -i conflicts &&
	shit checkout --theirs -- A &&
	shit add A &&
	FAKE_COMMIT_AMEND=edited shit rebase --continue &&
	test_cmp_rev HEAD^ conflicts &&
	test_cmp_rev HEAD^{tree} A1^{tree} &&
	test_commit_message HEAD expected-message &&
	get_author HEAD >actual-author &&
	test_cmp expected-author actual-author
'

test_expect_success 'skipping fixup -C after fixup gives correct message' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A3 &&
	test_must_fail env FAKE_LINES="1 fixup 2 fixup_-C 4" shit rebase -i A &&
	shit reset --hard &&
	FAKE_COMMIT_AMEND=edited shit rebase --continue &&
	test_commit_message HEAD -m "B"
'

test_expect_success 'sequence of fixup, fixup -C & squash --signoff works' '
	shit checkout --detach B3 &&
	FAKE_LINES="1 fixup 2 fixup_-C 3 fixup_-C 4 squash 5 fixup_-C 6" \
		FAKE_COMMIT_AMEND=squashed \
		FAKE_MESSAGE_COPY=actual-squash-message \
		shit -c commit.status=false rebase -ik --signoff A &&
	shit diff-tree --exit-code --patch HEAD B3 -- &&
	test_cmp_rev HEAD^ A &&
	test_cmp "$TEST_DIRECTORY/t3437/expected-squash-message" \
		actual-squash-message
'

test_expect_success 'first fixup -C commented out in sequence fixup fixup -C fixup -C' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach B2~ &&
	shit log -1 --pretty=format:%b >expected-message &&
	FAKE_LINES="1 fixup 2 fixup_-C 3 fixup_-C 4" shit rebase -i A &&
	test_cmp_rev HEAD^ A &&
	test_commit_message HEAD expected-message
'

test_expect_success 'multiple fixup -c opens editor once' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A3 &&
	shit log -1 --pretty=format:%B >expected-message &&
	test_write_lines "" "Modified-A3" >>expected-message &&
	FAKE_COMMIT_AMEND="Modified-A3" \
		FAKE_LINES="1 fixup_-C 2 fixup_-c 3 fixup_-c 4" \
		EXPECT_HEADER_COUNT=4 \
		shit rebase -i A &&
	test_cmp_rev HEAD^ A &&
	get_author HEAD >actual-author &&
	test_cmp expected-author actual-author &&
	test_commit_message HEAD expected-message
'

test_expect_success 'sequence squash, fixup & fixup -c gives combined message' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout --detach A3 &&
	FAKE_LINES="1 squash 2 fixup 3 fixup_-c 4" \
		FAKE_MESSAGE_COPY=actual-combined-message \
		shit -c commit.status=false rebase -i A &&
	test_cmp "$TEST_DIRECTORY/t3437/expected-combined-message" \
		actual-combined-message &&
	test_cmp_rev HEAD^ A
'

test_expect_success 'fixup -C works upon --autosquash with amend!' '
	shit checkout --detach B3 &&
	FAKE_COMMIT_AMEND=squashed \
		FAKE_MESSAGE_COPY=actual-squash-message \
		shit -c commit.status=false rebase -ik --autosquash \
						--signoff A &&
	shit diff-tree --exit-code --patch HEAD B3 -- &&
	test_cmp_rev HEAD^ A &&
	test_cmp "$TEST_DIRECTORY/t3437/expected-squash-message" \
		actual-squash-message
'

test_expect_success 'fixup -[Cc]<commit> works' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	cat >todo <<-\EOF &&
	pick A
	fixup -CA1
	pick B
	fixup -cA2
	EOF
	(
		set_replace_editor todo &&
		FAKE_COMMIT_MESSAGE="edited and fixed up" \
			shit rebase -i initial initial
	) &&
	shit log --pretty=format:%B initial.. >actual &&
	cat >expect <<-EOF &&
	edited and fixed up
	$EMPTY
	new subject
	$EMPTY
	new
	body
	EOF
	test_cmp expect actual
'

test_done
