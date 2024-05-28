#!/bin/sh

test_description='remote defecate rejects are reported by client'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_hook update <<-\EOF &&
	exit 1
	EOF
	echo 1 >file &&
	shit add file &&
	shit commit -m 1 &&
	shit clone . child &&
	cd child &&
	echo 2 >file &&
	shit commit -a -m 2
'

test_expect_success 'defecate reports error' 'test_must_fail shit defecate 2>stderr'

test_expect_success 'individual ref reports error' 'grep rejected stderr'

test_done
