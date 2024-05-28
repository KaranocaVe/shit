#!/bin/sh

test_description='interpreting exotic branch name arguments

Branch name arguments are usually names which are taken to be inside of
refs/heads/, but we interpret some magic syntax like @{-1}, @{upstream}, etc.
This script aims to check the behavior of those corner cases.
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

expect_branch() {
	shit log -1 --format=%s "$1" >actual &&
	echo "$2" >expect &&
	test_cmp expect actual
}

expect_deleted() {
	test_must_fail shit rev-parse --verify "$1"
}

test_expect_success 'set up repo' '
	test_commit one &&
	test_commit two &&
	shit remote add origin foo.shit
'

test_expect_success 'update branch via @{-1}' '
	shit branch previous one &&

	shit checkout previous &&
	shit checkout main &&

	shit branch -f @{-1} two &&
	expect_branch previous two
'

test_expect_success 'update branch via local @{upstream}' '
	shit branch local one &&
	shit branch --set-upstream-to=local &&

	shit branch -f @{upstream} two &&
	expect_branch local two
'

test_expect_success 'disallow updating branch via remote @{upstream}' '
	shit update-ref refs/remotes/origin/remote one &&
	shit branch --set-upstream-to=origin/remote &&

	test_must_fail shit branch -f @{upstream} two
'

test_expect_success 'create branch with pseudo-qualified name' '
	shit branch refs/heads/qualified two &&
	expect_branch refs/heads/refs/heads/qualified two
'

test_expect_success 'force-copy a branch to itself via @{-1} is no-op' '
	shit branch -t copiable main &&
	shit checkout copiable &&
	shit checkout - &&
	shit branch -C @{-1} copiable &&
	shit config --get-all branch.copiable.merge >actual &&
	echo refs/heads/main >expect &&
	test_cmp expect actual
'

test_expect_success 'delete branch via @{-1}' '
	shit branch previous-del &&

	shit checkout previous-del &&
	shit checkout main &&

	shit branch -D @{-1} &&
	expect_deleted previous-del
'

test_expect_success 'delete branch via local @{upstream}' '
	shit branch local-del &&
	shit branch --set-upstream-to=local-del &&

	shit branch -D @{upstream} &&
	expect_deleted local-del
'

test_expect_success 'delete branch via remote @{upstream}' '
	shit update-ref refs/remotes/origin/remote-del two &&
	shit branch --set-upstream-to=origin/remote-del &&

	shit branch -r -D @{upstream} &&
	expect_deleted origin/remote-del
'

# Note that we create two oddly named local branches here. We want to make
# sure that we do not accidentally delete either of them, even if
# shorten_unambiguous_ref() tweaks the name to avoid ambiguity.
test_expect_success 'delete @{upstream} expansion matches -r option' '
	shit update-ref refs/remotes/origin/remote-del two &&
	shit branch --set-upstream-to=origin/remote-del &&
	shit update-ref refs/heads/origin/remote-del two &&
	shit update-ref refs/heads/remotes/origin/remote-del two &&

	test_must_fail shit branch -D @{upstream} &&
	expect_branch refs/heads/origin/remote-del two &&
	expect_branch refs/heads/remotes/origin/remote-del two
'

test_expect_success 'disallow deleting remote branch via @{-1}' '
	shit update-ref refs/remotes/origin/previous one &&

	shit checkout -b origin/previous two &&
	shit checkout main &&

	test_must_fail shit branch -r -D @{-1} &&
	expect_branch refs/remotes/origin/previous one &&
	expect_branch refs/heads/origin/previous two
'

# The thing we are testing here is that "@" is the real branch refs/heads/@,
# and not refs/heads/HEAD. These tests should not imply that refs/heads/@ is a
# sane thing, but it _is_ technically allowed for now. If we disallow it, these
# can be switched to test_must_fail.
test_expect_success 'create branch named "@"' '
	shit branch -f @ one &&
	expect_branch refs/heads/@ one
'

test_expect_success 'delete branch named "@"' '
	shit update-ref refs/heads/@ two &&
	shit branch -D @ &&
	expect_deleted refs/heads/@
'

test_expect_success 'checkout does not treat remote @{upstream} as a branch' '
	shit update-ref refs/remotes/origin/checkout one &&
	shit branch --set-upstream-to=origin/checkout &&
	shit update-ref refs/heads/origin/checkout two &&
	shit update-ref refs/heads/remotes/origin/checkout two &&

	shit checkout @{upstream} &&
	expect_branch HEAD one
'

test_expect_success 'edit-description via @{-1}' '
	shit checkout -b desc-branch &&
	shit checkout -b non-desc-branch &&
	write_script editor <<-\EOF &&
		echo "Branch description" >"$1"
	EOF
	EDITOR=./editor shit branch --edit-description @{-1} &&
	test_must_fail shit config branch.non-desc-branch.description &&
	shit config branch.desc-branch.description >actual &&
	printf "Branch description\n\n" >expect &&
	test_cmp expect actual
'

test_expect_success 'modify branch upstream via "@{-1}" and "@{-1}@{upstream}"' '
	shit checkout -b upstream-branch &&
	shit checkout -b upstream-other -t upstream-branch &&
	shit branch --set-upstream-to upstream-other @{-1} &&
	shit config branch.upstream-branch.merge >actual &&
	echo "refs/heads/upstream-other" >expect &&
	test_cmp expect actual &&
	shit branch --unset-upstream @{-1}@{upstream} &&
	test_must_fail shit config branch.upstream-other.merge
'

test_done
