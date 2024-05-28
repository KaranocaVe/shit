#!/bin/sh

test_description='hunk edit with "commit -p -m"'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup (initial)' '
	echo line1 >file &&
	shit add file &&
	shit commit -m commit1
'

test_expect_success 'edit hunk "commit -p -m message"' '
	test_when_finished "rm -f editor_was_started" &&
	rm -f editor_was_started &&
	echo more >>file &&
	echo e | env shit_EDITOR=": >editor_was_started" shit commit -p -m commit2 file &&
	test -r editor_was_started
'

test_expect_success 'edit hunk "commit --dry-run -p -m message"' '
	test_when_finished "rm -f editor_was_started" &&
	rm -f editor_was_started &&
	echo more >>file &&
	echo e | env shit_EDITOR=": >editor_was_started" shit commit -p -m commit3 file &&
	test -r editor_was_started
'

test_done
