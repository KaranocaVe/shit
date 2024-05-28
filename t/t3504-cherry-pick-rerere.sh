#!/bin/sh

test_description='cherry-pick should rerere for conflicts'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	test_commit foo &&
	test_commit foo-main foo &&
	test_commit bar-main bar &&

	shit checkout -b dev foo &&
	test_commit foo-dev foo &&
	test_commit bar-dev bar &&
	shit config rerere.enabled true
'

test_expect_success 'conflicting merge' '
	test_must_fail shit merge main
'

test_expect_success 'fixup' '
	echo foo-resolved >foo &&
	echo bar-resolved >bar &&
	shit commit -am resolved &&
	cp foo foo-expect &&
	cp bar bar-expect &&
	shit reset --hard HEAD^
'

test_expect_success 'cherry-pick conflict with --rerere-autoupdate' '
	test_must_fail shit cherry-pick --rerere-autoupdate foo..bar-main &&
	test_cmp foo-expect foo &&
	shit diff-files --quiet &&
	test_must_fail shit cherry-pick --continue &&
	test_cmp bar-expect bar &&
	shit diff-files --quiet &&
	shit cherry-pick --continue &&
	shit reset --hard bar-dev
'

test_expect_success 'cherry-pick conflict repsects rerere.autoUpdate' '
	test_config rerere.autoUpdate true &&
	test_must_fail shit cherry-pick foo..bar-main &&
	test_cmp foo-expect foo &&
	shit diff-files --quiet &&
	test_must_fail shit cherry-pick --continue &&
	test_cmp bar-expect bar &&
	shit diff-files --quiet &&
	shit cherry-pick --continue &&
	shit reset --hard bar-dev
'

test_expect_success 'cherry-pick conflict with --no-rerere-autoupdate' '
	test_config rerere.autoUpdate true &&
	test_must_fail shit cherry-pick --no-rerere-autoupdate foo..bar-main &&
	test_cmp foo-expect foo &&
	test_must_fail shit diff-files --quiet &&
	shit add foo &&
	test_must_fail shit cherry-pick --continue &&
	test_cmp bar-expect bar &&
	test_must_fail shit diff-files --quiet &&
	shit add bar &&
	shit cherry-pick --continue &&
	shit reset --hard bar-dev
'

test_expect_success 'cherry-pick --continue rejects --rerere-autoupdate' '
	test_must_fail shit cherry-pick --rerere-autoupdate foo..bar-main &&
	test_cmp foo-expect foo &&
	shit diff-files --quiet &&
	test_must_fail shit cherry-pick --continue --rerere-autoupdate >actual 2>&1 &&
	echo "fatal: cherry-pick: --rerere-autoupdate cannot be used with --continue" >expect &&
	test_cmp expect actual &&
	test_must_fail shit cherry-pick --continue --no-rerere-autoupdate >actual 2>&1 &&
	echo "fatal: cherry-pick: --no-rerere-autoupdate cannot be used with --continue" >expect &&
	test_cmp expect actual &&
	shit cherry-pick --abort
'

test_expect_success 'cherry-pick --rerere-autoupdate more than once' '
	test_must_fail shit cherry-pick --rerere-autoupdate --rerere-autoupdate foo..bar-main &&
	test_cmp foo-expect foo &&
	shit diff-files --quiet &&
	shit cherry-pick --abort &&
	test_must_fail shit cherry-pick --rerere-autoupdate --no-rerere-autoupdate --rerere-autoupdate foo..bar-main &&
	test_cmp foo-expect foo &&
	shit diff-files --quiet &&
	shit cherry-pick --abort &&
	test_must_fail shit cherry-pick --rerere-autoupdate --no-rerere-autoupdate foo..bar-main &&
	test_must_fail shit diff-files --quiet &&
	shit cherry-pick --abort
'

test_expect_success 'cherry-pick conflict without rerere' '
	test_config rerere.enabled false &&
	test_must_fail shit cherry-pick foo-main &&
	grep ===== foo &&
	grep foo-dev foo &&
	grep foo-main foo
'

test_done
