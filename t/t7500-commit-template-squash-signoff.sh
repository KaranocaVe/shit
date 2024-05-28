#!/bin/sh
#
# Copyright (c) 2007 Steven Grimm
#

test_description='shit commit

Tests for template, signoff, squash and -F functions.'

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

commit_msg_is () {
	expect=commit_msg_is.expect
	actual=commit_msg_is.actual

	printf "%s" "$(shit log --pretty=format:%s%b -1)" >"$actual" &&
	printf "%s" "$1" >"$expect" &&
	test_cmp "$expect" "$actual"
}

# A sanity check to see if commit is working at all.
test_expect_success 'a basic commit in an empty tree should succeed' '
	echo content > foo &&
	shit add foo &&
	shit commit -m "initial commit"
'

test_expect_success 'nonexistent template file should return error' '
	echo changes >> foo &&
	shit add foo &&
	(
		shit_EDITOR="echo hello >\"\$1\"" &&
		export shit_EDITOR &&
		test_must_fail shit commit --template "$PWD"/notexist
	)
'

test_expect_success 'nonexistent template file in config should return error' '
	test_config commit.template "$PWD"/notexist &&
	(
		shit_EDITOR="echo hello >\"\$1\"" &&
		export shit_EDITOR &&
		test_must_fail shit commit
	)
'

# From now on we'll use a template file that exists.
TEMPLATE="$PWD"/template

test_expect_success 'unedited template should not commit' '
	echo "template line" > "$TEMPLATE" &&
	test_must_fail shit commit --template "$TEMPLATE"
'

test_expect_success 'unedited template with comments should not commit' '
	echo "# comment in template" >> "$TEMPLATE" &&
	test_must_fail shit commit --template "$TEMPLATE"
'

test_expect_success 'a Signed-off-by line by itself should not commit' '
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-signed-off &&
		test_must_fail shit commit --template "$TEMPLATE"
	)
'

test_expect_success 'adding comments to a template should not commit' '
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-comments &&
		test_must_fail shit commit --template "$TEMPLATE"
	)
'

test_expect_success 'adding real content to a template should commit' '
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-content &&
		shit commit --template "$TEMPLATE"
	) &&
	commit_msg_is "template linecommit message"
'

test_expect_success '-t option should be short for --template' '
	echo "short template" > "$TEMPLATE" &&
	echo "new content" >> foo &&
	shit add foo &&
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-content &&
		shit commit -t "$TEMPLATE"
	) &&
	commit_msg_is "short templatecommit message"
'

test_expect_success 'config-specified template should commit' '
	echo "new template" > "$TEMPLATE" &&
	test_config commit.template "$TEMPLATE" &&
	echo "more content" >> foo &&
	shit add foo &&
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-content &&
		shit commit
	) &&
	commit_msg_is "new templatecommit message"
'

test_expect_success 'explicit commit message should override template' '
	echo "still more content" >> foo &&
	shit add foo &&
	shit_EDITOR="$TEST_DIRECTORY"/t7500/add-content shit commit --template "$TEMPLATE" \
		-m "command line msg" &&
	commit_msg_is "command line msg"
'

test_expect_success 'commit message from file should override template' '
	echo "content galore" >> foo &&
	shit add foo &&
	echo "standard input msg" |
	(
		test_set_editor "$TEST_DIRECTORY"/t7500/add-content &&
		shit commit --template "$TEMPLATE" --file -
	) &&
	commit_msg_is "standard input msg"
'

cat >"$TEMPLATE" <<\EOF


### template

EOF
test_expect_success 'commit message from template with whitespace issue' '
	echo "content galore" >>foo &&
	shit add foo &&
	shit_EDITOR=\""$TEST_DIRECTORY"\"/t7500/add-whitespaced-content \
	shit commit --template "$TEMPLATE" &&
	commit_msg_is "commit message"
'

test_expect_success 'using alternate shit_INDEX_FILE (1)' '

	cp .shit/index saved-index &&
	(
		echo some new content >file &&
	        shit_INDEX_FILE=.shit/another_index &&
		export shit_INDEX_FILE &&
		shit add file &&
		shit commit -m "commit using another index" &&
		shit diff-index --exit-code HEAD &&
		shit diff-files --exit-code
	) &&
	cmp .shit/index saved-index >/dev/null

'

test_expect_success 'using alternate shit_INDEX_FILE (2)' '

	cp .shit/index saved-index &&
	(
		rm -f .shit/no-such-index &&
		shit_INDEX_FILE=.shit/no-such-index &&
		export shit_INDEX_FILE &&
		shit commit -m "commit using nonexistent index" &&
		test -z "$(shit ls-files)" &&
		test -z "$(shit ls-tree HEAD)"

	) &&
	cmp .shit/index saved-index >/dev/null
'

cat > expect << EOF
zort

Signed-off-by: C O Mitter <committer@example.com>
EOF

test_expect_success '--signoff' '
	echo "yet another content *narf*" >> foo &&
	echo "zort" | shit commit -s -F - foo &&
	shit cat-file commit HEAD | sed "1,/^\$/d" > output &&
	test_cmp expect output
'

test_expect_success 'commit message from file (1)' '
	mkdir subdir &&
	echo "Log in top directory" >log &&
	echo "Log in sub directory" >subdir/log &&
	(
		cd subdir &&
		shit commit --allow-empty -F log
	) &&
	commit_msg_is "Log in sub directory"
'

test_expect_success 'commit message from file (2)' '
	rm -f log &&
	echo "Log in sub directory" >subdir/log &&
	(
		cd subdir &&
		shit commit --allow-empty -F log
	) &&
	commit_msg_is "Log in sub directory"
'

test_expect_success 'commit message from stdin' '
	(
		cd subdir &&
		echo "Log with foo word" | shit commit --allow-empty -F -
	) &&
	commit_msg_is "Log with foo word"
'

test_expect_success 'commit -F overrides -t' '
	(
		cd subdir &&
		echo "-F log" > f.log &&
		echo "-t template" > t.template &&
		shit commit --allow-empty -F f.log -t t.template
	) &&
	commit_msg_is "-F log"
'

test_expect_success 'Commit without message is allowed with --allow-empty-message' '
	echo "more content" >>foo &&
	shit add foo &&
	>empty &&
	shit commit --allow-empty-message <empty &&
	commit_msg_is "" &&
	shit tag empty-message-commit
'

test_expect_success 'Commit without message is no-no without --allow-empty-message' '
	echo "more content" >>foo &&
	shit add foo &&
	>empty &&
	test_must_fail shit commit <empty
'

test_expect_success 'Commit a message with --allow-empty-message' '
	echo "even more content" >>foo &&
	shit add foo &&
	shit commit --allow-empty-message -m"hello there" &&
	commit_msg_is "hello there"
'

test_expect_success 'commit -C empty respects --allow-empty-message' '
	echo more >>foo &&
	shit add foo &&
	test_must_fail shit commit -C empty-message-commit &&
	shit commit -C empty-message-commit --allow-empty-message &&
	commit_msg_is ""
'

commit_for_rebase_autosquash_setup () {
	echo "first content line" >>foo &&
	shit add foo &&
	cat >log <<EOF &&
target message subject line

target message body line 1
target message body line 2
EOF
	shit commit -F log &&
	echo "second content line" >>foo &&
	shit add foo &&
	shit commit -m "intermediate commit" &&
	echo "third content line" >>foo &&
	shit add foo
}

test_expect_success 'commit --fixup provides correct one-line commit message' '
	commit_for_rebase_autosquash_setup &&
	EDITOR="echo ignored >>" shit commit --fixup HEAD~1 &&
	commit_msg_is "fixup! target message subject line"
'

test_expect_success 'commit --fixup -m"something" -m"extra"' '
	commit_for_rebase_autosquash_setup &&
	shit commit --fixup HEAD~1 -m"something" -m"extra" &&
	commit_msg_is "fixup! target message subject linesomething

extra"
'
test_expect_success 'commit --fixup --edit' '
	commit_for_rebase_autosquash_setup &&
	EDITOR="printf \"something\nextra\" >>" shit commit --fixup HEAD~1 --edit &&
	commit_msg_is "fixup! target message subject linesomething
extra"
'

get_commit_msg () {
	rev="$1" &&
	shit log -1 --pretty=format:"%B" "$rev"
}

test_expect_success 'commit --fixup=amend: creates amend! commit' '
	commit_for_rebase_autosquash_setup &&
	cat >expected <<-EOF &&
	amend! $(shit log -1 --format=%s HEAD~)

	$(get_commit_msg HEAD~)

	edited
	EOF
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="edited" \
			shit commit --fixup=amend:HEAD~
	) &&
	get_commit_msg HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--fixup=amend: --only ignores staged changes' '
	commit_for_rebase_autosquash_setup &&
	cat >expected <<-EOF &&
	amend! $(shit log -1 --format=%s HEAD~)

	$(get_commit_msg HEAD~)

	edited
	EOF
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="edited" \
			shit commit --fixup=amend:HEAD~ --only
	) &&
	get_commit_msg HEAD >actual &&
	test_cmp expected actual &&
	test_cmp_rev HEAD@{1}^{tree} HEAD^{tree} &&
	test_cmp_rev HEAD@{1} HEAD^ &&
	test_expect_code 1 shit diff --cached --exit-code &&
	shit cat-file blob :foo >actual &&
	test_cmp foo actual
'

test_expect_success '--fixup=reword: ignores staged changes' '
	commit_for_rebase_autosquash_setup &&
	cat >expected <<-EOF &&
	amend! $(shit log -1 --format=%s HEAD~)

	$(get_commit_msg HEAD~)

	edited
	EOF
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="edited" \
			shit commit --fixup=reword:HEAD~
	) &&
	get_commit_msg HEAD >actual &&
	test_cmp expected actual &&
	test_cmp_rev HEAD@{1}^{tree} HEAD^{tree} &&
	test_cmp_rev HEAD@{1} HEAD^ &&
	test_expect_code 1 shit diff --cached --exit-code &&
	shit cat-file blob :foo >actual &&
	test_cmp foo actual
'

test_expect_success '--fixup=reword: error out with -m option' '
	commit_for_rebase_autosquash_setup &&
	echo "fatal: options '\''-m'\'' and '\''--fixup:reword'\'' cannot be used together" >expect &&
	test_must_fail shit commit --fixup=reword:HEAD~ -m "reword commit message" 2>actual &&
	test_cmp expect actual
'

test_expect_success '--fixup=amend: error out with -m option' '
	commit_for_rebase_autosquash_setup &&
	echo "fatal: options '\''-m'\'' and '\''--fixup:amend'\'' cannot be used together" >expect &&
	test_must_fail shit commit --fixup=amend:HEAD~ -m "amend commit message" 2>actual &&
	test_cmp expect actual
'

test_expect_success 'consecutive amend! commits remove amend! line from commit msg body' '
	commit_for_rebase_autosquash_setup &&
	cat >expected <<-EOF &&
	amend! amend! $(shit log -1 --format=%s HEAD~)

	$(get_commit_msg HEAD~)

	edited 1

	edited 2
	EOF
	echo "reword new commit message" >actual &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="edited 1" \
			shit commit --fixup=reword:HEAD~ &&
		FAKE_COMMIT_AMEND="edited 2" \
			shit commit --fixup=reword:HEAD
	) &&
	get_commit_msg HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'deny to create amend! commit if its commit msg body is empty' '
	commit_for_rebase_autosquash_setup &&
	echo "Aborting commit due to empty commit message body." >expected &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_COMMIT_MESSAGE="amend! target message subject line" \
			shit commit --fixup=amend:HEAD~ 2>actual
	) &&
	test_cmp expected actual
'

test_expect_success 'amend! commit allows empty commit msg body with --allow-empty-message' '
	commit_for_rebase_autosquash_setup &&
	cat >expected <<-EOF &&
	amend! $(shit log -1 --format=%s HEAD~)
	EOF
	(
		set_fake_editor &&
		FAKE_COMMIT_MESSAGE="amend! target message subject line" \
			shit commit --fixup=amend:HEAD~ --allow-empty-message &&
		get_commit_msg HEAD >actual
	) &&
	test_cmp expected actual
'

test_fixup_reword_opt () {
	test_expect_success "--fixup=reword: incompatible with $1" "
		echo 'fatal: reword option of '\''--fixup'\'' and' \
			''\''--patch/--interactive/--all/--include/--only'\' \
			'cannot be used together' >expect &&
		test_must_fail shit commit --fixup=reword:HEAD~ $1 2>actual &&
		test_cmp expect actual
	"
}

for opt in --all --include --only --interactive --patch
do
	test_fixup_reword_opt $opt
done

test_expect_success '--fixup=reword: give error with pathsec' '
	commit_for_rebase_autosquash_setup &&
	echo "fatal: reword option of '\''--fixup'\'' and path '\''foo'\'' cannot be used together" >expect &&
	test_must_fail shit commit --fixup=reword:HEAD~ -- foo 2>actual &&
	test_cmp expect actual
'

test_expect_success '--fixup=reword: -F give error message' '
	echo "fatal: options '\''-F'\'' and '\''--fixup'\'' cannot be used together" >expect &&
	test_must_fail shit commit --fixup=reword:HEAD~ -F msg  2>actual &&
	test_cmp expect actual
'

test_expect_success 'commit --squash works with -F' '
	commit_for_rebase_autosquash_setup &&
	echo "log message from file" >msgfile &&
	shit commit --squash HEAD~1 -F msgfile  &&
	commit_msg_is "squash! target message subject linelog message from file"
'

test_expect_success 'commit --squash works with -m' '
	commit_for_rebase_autosquash_setup &&
	shit commit --squash HEAD~1 -m "foo bar\nbaz" &&
	commit_msg_is "squash! target message subject linefoo bar\nbaz"
'

test_expect_success 'commit --squash works with -C' '
	commit_for_rebase_autosquash_setup &&
	shit commit --squash HEAD~1 -C HEAD &&
	commit_msg_is "squash! target message subject lineintermediate commit"
'

test_expect_success 'commit --squash works with -c' '
	commit_for_rebase_autosquash_setup &&
	test_set_editor "$TEST_DIRECTORY"/t7500/edit-content &&
	shit commit --squash HEAD~1 -c HEAD &&
	commit_msg_is "squash! target message subject lineedited commit"
'

test_expect_success 'commit --squash works with -C for same commit' '
	commit_for_rebase_autosquash_setup &&
	shit commit --squash HEAD -C HEAD &&
	commit_msg_is "squash! intermediate commit"
'

test_expect_success 'commit --squash works with -c for same commit' '
	commit_for_rebase_autosquash_setup &&
	test_set_editor "$TEST_DIRECTORY"/t7500/edit-content &&
	shit commit --squash HEAD -c HEAD &&
	commit_msg_is "squash! edited commit"
'

test_expect_success 'commit --squash works with editor' '
	commit_for_rebase_autosquash_setup &&
	test_set_editor "$TEST_DIRECTORY"/t7500/add-content &&
	shit commit --squash HEAD~1 &&
	commit_msg_is "squash! target message subject linecommit message"
'

test_expect_success 'invalid message options when using --fixup' '
	echo changes >>foo &&
	echo "message" >log &&
	shit add foo &&
	test_must_fail shit commit --fixup HEAD~1 --squash HEAD~2 &&
	test_must_fail shit commit --fixup HEAD~1 -C HEAD~2 &&
	test_must_fail shit commit --fixup HEAD~1 -c HEAD~2 &&
	test_must_fail shit commit --fixup HEAD~1 -F log
'

cat >expected-template <<EOF

# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored.
#
# Author:    A U Thor <author@example.com>
#
# On branch commit-template-check
# Changes to be committed:
#	new file:   commit-template-check
#
# Untracked files not listed
EOF

test_expect_success 'new line found before status message in commit template' '
	shit checkout -b commit-template-check &&
	shit reset --hard HEAD &&
	touch commit-template-check &&
	shit add commit-template-check &&
	shit_EDITOR="cat >editor-input" shit commit --untracked-files=no --allow-empty-message &&
	test_cmp expected-template editor-input
'

test_expect_success 'setup empty commit with unstaged rename and copy' '
	test_create_repo unstaged_rename_and_copy &&
	(
		cd unstaged_rename_and_copy &&

		echo content >orig &&
		shit add orig &&
		test_commit orig &&

		cp orig new_copy &&
		mv orig new_rename &&
		shit add -N new_copy new_rename
	)
'

test_expect_success 'check commit with unstaged rename and copy' '
	(
		cd unstaged_rename_and_copy &&

		test_must_fail shit -c diff.renames=copy commit
	)
'

test_expect_success 'commit without staging files fails and displays hints' '
	echo "initial" >file &&
	shit add file &&
	shit commit -m initial &&
	echo "changes" >>file &&
	test_must_fail shit commit -m update >actual &&
	test_grep "no changes added to commit (use \"shit add\" and/or \"shit commit -a\")" actual
'

test_done
