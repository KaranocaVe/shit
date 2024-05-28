#!/bin/sh

test_description='prepare-commit-msg hook'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'set up commits for rebasing' '
	test_commit root &&
	test_commit a a a &&
	test_commit b b b &&
	shit checkout -b rebase-me root &&
	test_commit rebase-a a aa &&
	test_commit rebase-b b bb &&
	for i in $(test_seq 1 13)
	do
		test_commit rebase-$i c $i || return 1
	done &&
	shit checkout main &&

	cat >rebase-todo <<-EOF
	pick $(shit rev-parse rebase-a)
	pick $(shit rev-parse rebase-b)
	fixup $(shit rev-parse rebase-1)
	fixup $(shit rev-parse rebase-2)
	pick $(shit rev-parse rebase-3)
	fixup $(shit rev-parse rebase-4)
	squash $(shit rev-parse rebase-5)
	reword $(shit rev-parse rebase-6)
	squash $(shit rev-parse rebase-7)
	fixup $(shit rev-parse rebase-8)
	fixup $(shit rev-parse rebase-9)
	edit $(shit rev-parse rebase-10)
	squash $(shit rev-parse rebase-11)
	squash $(shit rev-parse rebase-12)
	edit $(shit rev-parse rebase-13)
	EOF
'

test_expect_success 'with no hook' '

	echo "foo" > file &&
	shit add file &&
	shit commit -m "first"

'

test_expect_success 'setup fake editor for interactive editing' '
	write_script fake-editor <<-\EOF &&
	exit 0
	EOF

	## Not using test_set_editor here so we can easily ensure the editor variable
	## is only set for the editor tests
	FAKE_EDITOR="$(pwd)/fake-editor" &&
	export FAKE_EDITOR
'

test_expect_success 'setup prepare-commit-msg hook' '
	test_hook --setup prepare-commit-msg <<\EOF
shit_DIR=$(shit rev-parse --shit-dir)
if test -d "$shit_DIR/rebase-merge"
then
	rebasing=1
else
	rebasing=0
fi

get_last_cmd () {
	tail -n1 "$shit_DIR/rebase-merge/done" | {
		read cmd id _
		shit log --pretty="[$cmd %s]" -n1 $id
	}
}

if test "$2" = commit
then
	if test $rebasing = 1
	then
		source="$3"
	else
		source=$(shit rev-parse "$3")
	fi
else
	source=${2-default}
fi
test "$shit_EDITOR" = : && source="$source (no editor)"

if test $rebasing = 1
then
	echo "$source $(get_last_cmd)" >"$1"
else
	sed -e "1s/.*/$source/" "$1" >msg.tmp
	mv msg.tmp "$1"
fi
exit 0
EOF
'

echo dummy template > "$(shit rev-parse --shit-dir)/template"

test_expect_success 'with hook (-m)' '

	echo "more" >> file &&
	shit add file &&
	shit commit -m "more" &&
	test "$(shit log -1 --pretty=format:%s)" = "message (no editor)"

'

test_expect_success 'with hook (-m editor)' '

	echo "more" >> file &&
	shit add file &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit -e -m "more more" &&
	test "$(shit log -1 --pretty=format:%s)" = message

'

test_expect_success 'with hook (-t)' '

	echo "more" >> file &&
	shit add file &&
	shit commit -t "$(shit rev-parse --shit-dir)/template" &&
	test "$(shit log -1 --pretty=format:%s)" = template

'

test_expect_success 'with hook (-F)' '

	echo "more" >> file &&
	shit add file &&
	(echo more | shit commit -F -) &&
	test "$(shit log -1 --pretty=format:%s)" = "message (no editor)"

'

test_expect_success 'with hook (-F editor)' '

	echo "more" >> file &&
	shit add file &&
	(echo more more | shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit -e -F -) &&
	test "$(shit log -1 --pretty=format:%s)" = message

'

test_expect_success 'with hook (-C)' '

	head=$(shit rev-parse HEAD) &&
	echo "more" >> file &&
	shit add file &&
	shit commit -C $head &&
	test "$(shit log -1 --pretty=format:%s)" = "$head (no editor)"

'

test_expect_success 'with hook (editor)' '

	echo "more more" >> file &&
	shit add file &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit &&
	test "$(shit log -1 --pretty=format:%s)" = default

'

test_expect_success 'with hook (--amend)' '

	head=$(shit rev-parse HEAD) &&
	echo "more" >> file &&
	shit add file &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --amend &&
	test "$(shit log -1 --pretty=format:%s)" = "$head"

'

test_expect_success 'with hook (-c)' '

	head=$(shit rev-parse HEAD) &&
	echo "more" >> file &&
	shit add file &&
	shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit -c $head &&
	test "$(shit log -1 --pretty=format:%s)" = "$head"

'

test_expect_success 'with hook (merge)' '

	test_when_finished "shit checkout -f main" &&
	shit checkout -B other HEAD@{1} &&
	echo "more" >>file &&
	shit add file &&
	shit commit -m other &&
	shit checkout - &&
	shit merge --no-ff other &&
	test "$(shit log -1 --pretty=format:%s)" = "merge (no editor)"
'

test_expect_success 'with hook and editor (merge)' '

	test_when_finished "shit checkout -f main" &&
	shit checkout -B other HEAD@{1} &&
	echo "more" >>file &&
	shit add file &&
	shit commit -m other &&
	shit checkout - &&
	env shit_EDITOR="\"\$FAKE_EDITOR\"" shit merge --no-ff -e other &&
	test "$(shit log -1 --pretty=format:%s)" = "merge"
'

test_rebase () {
	expect=$1 &&
	mode=$2 &&
	test_expect_$expect "with hook (rebase ${mode:--i})" '
		test_when_finished "\
			shit rebase --abort
			shit checkout -f main
			shit branch -D tmp" &&
		shit checkout -b tmp rebase-me &&
		shit_SEQUENCE_EDITOR="cp rebase-todo" &&
		shit_EDITOR="\"$FAKE_EDITOR\"" &&
		(
			export shit_SEQUENCE_EDITOR shit_EDITOR &&
			test_must_fail shit rebase -i $mode b &&
			echo x >a &&
			shit add a &&
			test_must_fail shit rebase --continue &&
			echo x >b &&
			shit add b &&
			shit commit &&
			shit rebase --continue &&
			echo y >a &&
			shit add a &&
			shit commit &&
			shit rebase --continue &&
			echo y >b &&
			shit add b &&
			shit rebase --continue
		) &&
		shit log --pretty=%s -g -n18 HEAD@{1} >actual &&
		test_cmp "$TEST_DIRECTORY/t7505/expected-rebase${mode:--i}" actual
	'
}

test_rebase success

test_expect_success 'with hook (cherry-pick)' '
	test_when_finished "shit checkout -f main" &&
	shit checkout -B other b &&
	shit cherry-pick rebase-1 &&
	test "$(shit log -1 --pretty=format:%s)" = "message (no editor)"
'

test_expect_success 'with hook and editor (cherry-pick)' '
	test_when_finished "shit checkout -f main" &&
	shit checkout -B other b &&
	shit cherry-pick -e rebase-1 &&
	test "$(shit log -1 --pretty=format:%s)" = merge
'

test_expect_success 'setup: commit-msg hook that always fails' '
	test_hook --setup --clobber prepare-commit-msg <<-\EOF
	exit 1
	EOF
'

test_expect_success 'with failing hook' '

	test_when_finished "shit checkout -f main" &&
	head=$(shit rev-parse HEAD) &&
	echo "more" >> file &&
	shit add file &&
	test_must_fail env shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit -c $head

'

test_expect_success 'with failing hook (--no-verify)' '

	test_when_finished "shit checkout -f main" &&
	head=$(shit rev-parse HEAD) &&
	echo "more" >> file &&
	shit add file &&
	test_must_fail env shit_EDITOR="\"\$FAKE_EDITOR\"" shit commit --no-verify -c $head

'

test_expect_success 'with failing hook (merge)' '

	test_when_finished "shit checkout -f main" &&
	shit checkout -B other HEAD@{1} &&
	echo "more" >> file &&
	shit add file &&
	test_hook --remove prepare-commit-msg &&
	shit commit -m other &&
	test_hook --setup prepare-commit-msg <<-\EOF &&
	exit 1
	EOF
	shit checkout - &&
	test_must_fail shit merge --no-ff other

'

test_expect_success 'with failing hook (cherry-pick)' '
	test_when_finished "shit checkout -f main" &&
	shit checkout -B other b &&
	test_must_fail shit cherry-pick rebase-1 2>actual &&
	test $(grep -c prepare-commit-msg actual) = 1
'

test_done
