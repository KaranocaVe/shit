#!/bin/sh

test_description='rebase should reread the todo file if an exec modifies it'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	test_commit first file &&
	test_commit second file &&
	test_commit third file
'

test_expect_success 'rebase exec modifies rebase-todo' '
	todo=.shit/rebase-merge/shit-rebase-todo &&
	shit rebase HEAD~1 -x "echo exec touch F >>$todo" &&
	test -e F
'

test_expect_success 'rebase exec with an empty list does not exec anything' '
	shit rebase HEAD -x "true" 2>output &&
	! grep "Executing: true" output
'

test_expect_success 'loose object cache vs re-reading todo list' '
	shit_REBASE_TODO=.shit/rebase-merge/shit-rebase-todo &&
	export shit_REBASE_TODO &&
	write_script append-todo.sh <<-\EOS &&
	# For values 5 and 6, this yields SHA-1s with the same first two dishits
	echo "pick $(shit rev-parse --short \
		$(printf "%s\\n" \
			"tree $EMPTY_TREE" \
			"author A U Thor <author@example.org> $1 +0000" \
			"committer A U Thor <author@example.org> $1 +0000" \
			"" \
			"$1" |
		  shit hash-object -t commit -w --stdin))" >>$shit_REBASE_TODO

	shift
	test -z "$*" ||
	echo "exec $0 $*" >>$shit_REBASE_TODO
	EOS

	shit rebase HEAD -x "./append-todo.sh 5 6"
'

test_expect_success 'todo is re-read after reword and squash' '
	write_script reword-editor.sh <<-\EOS &&
	shit_SEQUENCE_EDITOR="echo \"exec echo $(cat file) >>actual\" >>" \
		shit rebase --edit-todo
	EOS

	test_write_lines first third >expected &&
	set_fake_editor &&
	shit_SEQUENCE_EDITOR="$EDITOR" FAKE_LINES="reword 1 squash 2 fixup 3" \
		shit_EDITOR=./reword-editor.sh shit rebase -i --root third &&
	test_cmp expected actual
'

test_expect_success 're-reading todo doesnt interfere with revert --edit' '
	shit reset --hard third &&

	shit revert --edit third second &&

	cat >expect <<-\EOF &&
	Revert "second"
	Revert "third"
	third
	second
	first
	EOF
	shit log --format="%s" >actual &&
	test_cmp expect actual
'

test_expect_success 're-reading todo doesnt interfere with cherry-pick --edit' '
	shit reset --hard first &&

	shit cherry-pick --edit second third &&

	cat >expect <<-\EOF &&
	third
	second
	first
	EOF
	shit log --format="%s" >actual &&
	test_cmp expect actual
'

test_done
