#!/bin/sh

test_description='test auto-generated merge messages'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_oneline() {
	echo "$1" | sed "s/Q/'/g" >expect &&
	shit log -1 --pretty=tformat:%s >actual &&
	test_cmp expect actual
}

test_expect_success 'merge local branch' '
	test_commit main-1 &&
	shit checkout -b local-branch &&
	test_commit branch-1 &&
	shit checkout main &&
	test_commit main-2 &&
	shit merge local-branch &&
	check_oneline "Merge branch Qlocal-branchQ"
'

test_expect_success 'merge octopus branches' '
	shit checkout -b octopus-a main &&
	test_commit octopus-1 &&
	shit checkout -b octopus-b main &&
	test_commit octopus-2 &&
	shit checkout main &&
	shit merge octopus-a octopus-b &&
	check_oneline "Merge branches Qoctopus-aQ and Qoctopus-bQ"
'

test_expect_success 'merge tag' '
	shit checkout -b tag-branch main &&
	test_commit tag-1 &&
	shit checkout main &&
	test_commit main-3 &&
	shit merge tag-1 &&
	check_oneline "Merge tag Qtag-1Q"
'

test_expect_success 'ambiguous tag' '
	shit checkout -b ambiguous main &&
	test_commit ambiguous &&
	shit checkout main &&
	test_commit main-4 &&
	shit merge ambiguous &&
	check_oneline "Merge tag QambiguousQ"
'

test_expect_success 'remote-tracking branch' '
	shit checkout -b remote main &&
	test_commit remote-1 &&
	shit update-ref refs/remotes/origin/main remote &&
	shit checkout main &&
	test_commit main-5 &&
	shit merge origin/main &&
	check_oneline "Merge remote-tracking branch Qorigin/mainQ"
'

test_done
