#!/bin/sh

test_description='diff with assume-unchanged entries'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# external diff has been tested in t4020-diff-external.sh

test_expect_success 'setup' '
	echo zero > zero &&
	shit add zero &&
	shit commit -m zero &&
	echo one > one &&
	echo two > two &&
	blob=$(shit hash-object one) &&
	shit add one two &&
	shit commit -m onetwo &&
	shit update-index --assume-unchanged one &&
	echo borked >> one &&
	test "$(shit ls-files -v one)" = "h one"
'

test_expect_success 'diff-index does not examine assume-unchanged entries' '
	shit diff-index HEAD^ -- one | grep -q $blob
'

test_expect_success 'diff-files does not examine assume-unchanged entries' '
	rm one &&
	test -z "$(shit diff-files -- one)"
'

test_expect_success POSIXPERM 'find-copies-harder is not confused by mode bits' '
	echo content >exec &&
	chmod +x exec &&
	shit add exec &&
	shit commit -m exec &&
	shit update-index --assume-unchanged exec &&
	shit diff-files --find-copies-harder -- exec >actual &&
	test_must_be_empty actual
'

test_done
