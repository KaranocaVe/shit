#!/bin/sh

test_description='ignored hook warning'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_hook --setup pre-commit <<-\EOF
	exit 0
	EOF
'

test_expect_success 'no warning if hook is not ignored' '
	shit commit --allow-empty -m "more" 2>message &&
	test_grep ! -e "hook was ignored" message
'

test_expect_success POSIXPERM 'warning if hook is ignored' '
	test_hook --disable pre-commit &&
	shit commit --allow-empty -m "even more" 2>message &&
	test_grep -e "hook was ignored" message
'

test_expect_success POSIXPERM 'no warning if advice.ignoredHook set to false' '
	test_config advice.ignoredHook false &&
	test_hook --disable pre-commit &&
	shit commit --allow-empty -m "even more" 2>message &&
	test_grep ! -e "hook was ignored" message
'

test_expect_success 'no warning if unset advice.ignoredHook and hook removed' '
	test_hook --remove pre-commit &&
	test_unconfig advice.ignoredHook &&
	shit commit --allow-empty -m "even more" 2>message &&
	test_grep ! -e "hook was ignored" message
'

test_done
