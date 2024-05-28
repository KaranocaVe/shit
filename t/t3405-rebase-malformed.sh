#!/bin/sh

test_description='rebase should handle arbitrary shit message'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

cat >F <<\EOF
This is an example of a commit log message
that does not  conform to shit commit convention.

It has two paragraphs, but its first paragraph is not friendly
to oneline summary format.
EOF

cat >G <<\EOF
commit log message containing a diff
EOF


test_expect_success setup '

	>file1 &&
	>file2 &&
	shit add file1 file2 &&
	test_tick &&
	shit commit -m "Initial commit" &&
	shit branch diff-in-message &&
	shit branch empty-message-merge &&

	shit checkout -b multi-line-subject &&
	cat F >file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -F F &&

	shit cat-file commit HEAD | sed -e "1,/^\$/d" >F0 &&

	shit checkout diff-in-message &&
	echo "commit log message containing a diff" >G &&
	echo "" >>G &&
	cat G >file2 &&
	shit add file2 &&
	shit diff --cached >>G &&
	test_tick &&
	shit commit -F G &&

	shit cat-file commit HEAD | sed -e "1,/^\$/d" >G0 &&

	shit checkout empty-message-merge &&
	echo file3 >file3 &&
	shit add file3 &&
	shit commit --allow-empty-message -m "" &&

	shit checkout main &&

	echo One >file1 &&
	test_tick &&
	shit add file1 &&
	shit commit -m "Second commit"
'

test_expect_success 'rebase commit with multi-line subject' '

	shit rebase main multi-line-subject &&
	shit cat-file commit HEAD | sed -e "1,/^\$/d" >F1 &&

	test_cmp F0 F1 &&
	test_cmp F F0
'

test_expect_success 'rebase commit with diff in message' '
	shit rebase main diff-in-message &&
	shit cat-file commit HEAD | sed -e "1,/^$/d" >G1 &&
	test_cmp G0 G1 &&
	test_cmp G G0
'

test_expect_success 'rebase -m commit with empty message' '
	shit rebase -m main empty-message-merge
'

test_expect_success 'rebase -i commit with empty message' '
	shit checkout diff-in-message &&
	set_fake_editor &&
	test_must_fail env FAKE_COMMIT_MESSAGE=" " FAKE_LINES="reword 1" \
		shit rebase -i HEAD^
'

test_done
