#!/bin/sh

test_description='shit rebase --signoff

This test runs shit rebase --signoff and make sure that it works.
'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	shit commit --allow-empty -m "Initial empty commit" &&
	test_commit first file a &&
	test_commit second file &&
	shit checkout -b conflict-branch first &&
	test_commit file-2 file-2 &&
	test_commit conflict file &&
	test_commit third file &&

	ident="$shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>" &&

	# Expected commit message for initial commit after rebase --signoff
	cat >expected-initial-signed <<-EOF &&
	Initial empty commit

	Signed-off-by: $ident
	EOF

	# Expected commit message after rebase --signoff
	cat >expected-signed <<-EOF &&
	first

	Signed-off-by: $ident
	EOF

	# Expected commit message after conflict resolution for rebase --signoff
	cat >expected-signed-conflict <<-EOF &&
	third

	Signed-off-by: $ident

	conflict

	Signed-off-by: $ident

	file-2

	Signed-off-by: $ident

	EOF

	# Expected commit message after rebase without --signoff (or with --no-signoff)
	cat >expected-unsigned <<-EOF &&
	first
	EOF

	shit config alias.rbs "rebase --signoff"
'

# We configure an alias to do the rebase --signoff so that
# on the next subtest we can show that --no-signoff overrides the alias
test_expect_success 'rebase --apply --signoff adds a sign-off line' '
	test_must_fail shit rbs --apply second third &&
	shit checkout --theirs file &&
	shit add file &&
	shit rebase --continue &&
	shit log --format=%B -n3 >actual &&
	test_cmp expected-signed-conflict actual
'

test_expect_success 'rebase --no-signoff does not add a sign-off line' '
	shit commit --amend -m "first" &&
	shit rbs --no-signoff HEAD^ &&
	test_commit_message HEAD expected-unsigned
'

test_expect_success 'rebase --exec --signoff adds a sign-off line' '
	test_when_finished "rm exec" &&
	shit rebase --exec "touch exec" --signoff first^ first &&
	test_path_is_file exec &&
	test_commit_message HEAD expected-signed
'

test_expect_success 'rebase --root --signoff adds a sign-off line' '
	shit checkout first &&
	shit rebase --root --keep-empty --signoff &&
	test_commit_message HEAD^ expected-initial-signed &&
	test_commit_message HEAD expected-signed
'

test_expect_success 'rebase -m --signoff adds a sign-off line' '
	test_must_fail shit rebase -m --signoff second third &&
	shit checkout --theirs file &&
	shit add file &&
	shit_EDITOR="sed -n /Conflicts:/,/^\\\$/p >actual" \
		shit rebase --continue &&
	cat >expect <<-\EOF &&
	# Conflicts:
	#	file

	EOF
	test_cmp expect actual &&
	shit log --format=%B -n3 >actual &&
	test_cmp expected-signed-conflict actual
'

test_expect_success 'rebase -i --signoff adds a sign-off line when editing commit' '
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 edit 3 edit 2" \
			shit rebase -i --signoff first third
	) &&
	echo a >a &&
	shit add a &&
	test_must_fail shit rebase --continue &&
	shit checkout --ours file &&
	echo b >a &&
	shit add a file &&
	shit rebase --continue &&
	echo c >a &&
	shit add a &&
	shit log --format=%B -n3 >actual &&
	cat >expect <<-EOF &&
	conflict

	Signed-off-by: $ident

	third

	Signed-off-by: $ident

	file-2

	Signed-off-by: $ident

	EOF
	test_cmp expect actual
'

test_done
