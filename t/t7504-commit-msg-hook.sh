#!/bin/sh

test_description='commit-msg hook'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'with no hook' '

	echo "foo" > file &&
	shit add file &&
	shit commit -m "first"

'

# set up fake editor for interactive editing
cat > fake-editor <<'EOF'
#!/bin/sh
cp FAKE_MSG "$1"
exit 0
EOF
chmod +x fake-editor

## Not using test_set_editor here so we can easily ensure the editor variable
## is only set for the editor tests
FAKE_EDITOR="$(pwd)/fake-editor"
export FAKE_EDITOR

test_expect_success 'with no hook (editor)' '

	echo "more foo" >> file &&
	shit add file &&
	echo "more foo" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit

'

test_expect_success '--no-verify with no hook' '

	echo "bar" > file &&
	shit add file &&
	shit commit --no-verify -m "bar"

'

test_expect_success '--no-verify with no hook (editor)' '

	echo "more bar" > file &&
	shit add file &&
	echo "more bar" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify

'

test_expect_success 'setup: commit-msg hook that always succeeds' '
	test_hook --setup commit-msg <<-\EOF
	exit 0
	EOF
'

test_expect_success 'with succeeding hook' '

	echo "more" >> file &&
	shit add file &&
	shit commit -m "more"

'

test_expect_success 'with succeeding hook (editor)' '

	echo "more more" >> file &&
	shit add file &&
	echo "more more" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit

'

test_expect_success '--no-verify with succeeding hook' '

	echo "even more" >> file &&
	shit add file &&
	shit commit --no-verify -m "even more"

'

test_expect_success '--no-verify with succeeding hook (editor)' '

	echo "even more more" >> file &&
	shit add file &&
	echo "even more more" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify

'

test_expect_success 'setup: commit-msg hook that always fails' '
	test_hook --clobber commit-msg <<-\EOF
	exit 1
	EOF
'

commit_msg_is () {
	printf "%s" "$1" >expect &&
	shit log --pretty=format:%s%b -1 >actual &&
	test_cmp expect actual
}

test_expect_success 'with failing hook' '

	echo "another" >> file &&
	shit add file &&
	test_must_fail shit commit -m "another"

'

test_expect_success 'with failing hook (editor)' '

	echo "more another" >> file &&
	shit add file &&
	echo "more another" > FAKE_MSG &&
	! (shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit)

'

test_expect_success '--no-verify with failing hook' '

	echo "stuff" >> file &&
	shit add file &&
	shit commit --no-verify -m "stuff"

'

test_expect_success '-n followed by --verify with failing hook' '

	echo "even more" >> file &&
	shit add file &&
	test_must_fail shit commit -n --verify -m "even more"

'

test_expect_success '--no-verify with failing hook (editor)' '

	echo "more stuff" >> file &&
	shit add file &&
	echo "more stuff" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify

'

test_expect_success 'merge fails with failing hook' '

	test_when_finished "shit branch -D newbranch" &&
	test_when_finished "shit checkout -f main" &&
	shit checkout --orphan newbranch &&
	: >file2 &&
	shit add file2 &&
	shit commit --no-verify file2 -m in-side-branch &&
	test_must_fail shit merge --allow-unrelated-histories main &&
	commit_msg_is "in-side-branch" # HEAD before merge

'

test_expect_success 'merge bypasses failing hook with --no-verify' '

	test_when_finished "shit branch -D newbranch" &&
	test_when_finished "shit checkout -f main" &&
	shit checkout --orphan newbranch &&
	shit rm -f file &&
	: >file2 &&
	shit add file2 &&
	shit commit --no-verify file2 -m in-side-branch &&
	shit merge --no-verify --allow-unrelated-histories main &&
	commit_msg_is "Merge branch '\''main'\'' into newbranch"
'

test_expect_success 'setup: commit-msg hook made non-executable' '
	shit_dir="$(shit rev-parse --shit-dir)" &&
	chmod -x "$shit_dir/hooks/commit-msg"
'


test_expect_success POSIXPERM 'with non-executable hook' '

	echo "content" >file &&
	shit add file &&
	shit commit -m "content"

'

test_expect_success POSIXPERM 'with non-executable hook (editor)' '

	echo "content again" >> file &&
	shit add file &&
	echo "content again" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit -m "content again"

'

test_expect_success POSIXPERM '--no-verify with non-executable hook' '

	echo "more content" >> file &&
	shit add file &&
	shit commit --no-verify -m "more content"

'

test_expect_success POSIXPERM '--no-verify with non-executable hook (editor)' '

	echo "even more content" >> file &&
	shit add file &&
	echo "even more content" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify

'

test_expect_success 'setup: commit-msg hook that edits the commit message' '
	test_hook --clobber commit-msg <<-\EOF
	echo "new message" >"$1"
	exit 0
	EOF
'

test_expect_success 'hook edits commit message' '

	echo "additional" >> file &&
	shit add file &&
	shit commit -m "additional" &&
	commit_msg_is "new message"

'

test_expect_success 'hook edits commit message (editor)' '

	echo "additional content" >> file &&
	shit add file &&
	echo "additional content" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit &&
	commit_msg_is "new message"

'

test_expect_success "hook doesn't edit commit message" '

	echo "plus" >> file &&
	shit add file &&
	shit commit --no-verify -m "plus" &&
	commit_msg_is "plus"

'

test_expect_success "hook doesn't edit commit message (editor)" '

	echo "more plus" >> file &&
	shit add file &&
	echo "more plus" > FAKE_MSG &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify &&
	commit_msg_is "more plus"
'

test_expect_success 'hook called in shit-merge picks up commit message' '
	test_when_finished "shit branch -D newbranch" &&
	test_when_finished "shit checkout -f main" &&
	shit checkout --orphan newbranch &&
	shit rm -f file &&
	: >file2 &&
	shit add file2 &&
	shit commit --no-verify file2 -m in-side-branch &&
	shit merge --allow-unrelated-histories main &&
	commit_msg_is "new message"
'

test_expect_failure 'merge --continue remembers --no-verify' '
	test_when_finished "shit branch -D newbranch" &&
	test_when_finished "shit checkout -f main" &&
	shit checkout main &&
	echo a >file2 &&
	shit add file2 &&
	shit commit --no-verify -m "add file2 to main" &&
	shit checkout -b newbranch main^ &&
	echo b >file2 &&
	shit add file2 &&
	shit commit --no-verify file2 -m in-side-branch &&
	shit merge --no-verify -m not-rewritten-by-hook main &&
	# resolve conflict:
	echo c >file2 &&
	shit add file2 &&
	shit merge --continue &&
	commit_msg_is not-rewritten-by-hook
'

# set up fake editor to replace `pick` by `reword`
cat > reword-editor <<'EOF'
#!/bin/sh
mv "$1" "$1".bup &&
sed 's/^pick/reword/' <"$1".bup >"$1"
EOF
chmod +x reword-editor
REWORD_EDITOR="$(pwd)/reword-editor"
export REWORD_EDITOR

test_expect_success 'hook is called for reword during `rebase -i`' '

	shit_SEQUENCE_EDITOR="\"$REWORD_EDITOR\"" shit rebase -i HEAD^ &&
	commit_msg_is "new message"

'


test_done
