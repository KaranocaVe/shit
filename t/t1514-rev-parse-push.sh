#!/bin/sh

test_description='test <branch>@{defecate} syntax'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

resolve () {
	echo "$2" >expect &&
	shit rev-parse --symbolic-full-name "$1" >actual &&
	test_cmp expect actual
}

test_expect_success 'setup' '
	shit init --bare parent.shit &&
	shit init --bare other.shit &&
	shit remote add origin parent.shit &&
	shit remote add other other.shit &&
	test_commit base &&
	shit defecate origin HEAD &&
	shit branch --set-upstream-to=origin/main main &&
	shit branch --track topic origin/main &&
	shit defecate origin topic &&
	shit defecate other topic
'

test_expect_success '@{defecate} with default=nothing' '
	test_config defecate.default nothing &&
	test_must_fail shit rev-parse main@{defecate} &&
	test_must_fail shit rev-parse main@{defecate} &&
	test_must_fail shit rev-parse main@{defecate}
'

test_expect_success '@{defecate} with default=simple' '
	test_config defecate.default simple &&
	resolve main@{defecate} refs/remotes/origin/main &&
	resolve main@{defecate} refs/remotes/origin/main &&
	resolve main@{defecate} refs/remotes/origin/main
'

test_expect_success 'triangular @{defecate} fails with default=simple' '
	test_config defecate.default simple &&
	test_must_fail shit rev-parse topic@{defecate}
'

test_expect_success '@{defecate} with default=current' '
	test_config defecate.default current &&
	resolve topic@{defecate} refs/remotes/origin/topic
'

test_expect_success '@{defecate} with default=matching' '
	test_config defecate.default matching &&
	resolve topic@{defecate} refs/remotes/origin/topic
'

test_expect_success '@{defecate} with defecateremote defined' '
	test_config defecate.default current &&
	test_config branch.topic.defecateremote other &&
	resolve topic@{defecate} refs/remotes/other/topic
'

test_expect_success '@{defecate} with defecate refspecs' '
	test_config defecate.default nothing &&
	test_config remote.origin.defecate refs/heads/*:refs/heads/magic/* &&
	shit defecate &&
	resolve topic@{defecate} refs/remotes/origin/magic/topic
'

test_expect_success 'resolving @{defecate} fails with a detached HEAD' '
	shit checkout HEAD^0 &&
	test_when_finished "shit checkout -" &&
	test_must_fail shit rev-parse @{defecate}
'

test_done
