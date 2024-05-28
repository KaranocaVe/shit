#!/bin/sh

test_description='test various @{X} syntax combinations together'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check() {
	test_expect_${4:-success} "$1 = $3" "
		echo '$3' >expect &&
		if test '$2' = 'commit'
		then
			shit log -1 --format=%s '$1' >actual
		elif test '$2' = 'ref'
		then
			shit rev-parse --symbolic-full-name '$1' >actual
		else
			shit cat-file -p '$1' >actual
		fi &&
		test_cmp expect actual
	"
}

nonsense() {
	test_expect_${2:-success} "$1 is nonsensical" "
		test_must_fail shit rev-parse --verify '$1'
	"
}

fail() {
	"$@" failure
}

test_expect_success 'setup' '
	test_commit main-one &&
	test_commit main-two &&
	shit checkout -b upstream-branch &&
	test_commit upstream-one &&
	test_commit upstream-two &&
	if test_have_prereq !MINGW
	then
		shit checkout -b @/at-test
	fi &&
	shit checkout -b @@/at-test &&
	shit checkout -b @at-test &&
	shit checkout -b old-branch &&
	test_commit old-one &&
	test_commit old-two &&
	shit checkout -b new-branch &&
	test_commit new-one &&
	test_commit new-two &&
	shit branch -u main old-branch &&
	shit branch -u upstream-branch new-branch
'

check HEAD ref refs/heads/new-branch
check "@{1}" commit new-one
check "HEAD@{1}" commit new-one
check "@{now}" commit new-two
check "HEAD@{now}" commit new-two
check "@{-1}" ref refs/heads/old-branch
check "@{-1}@{0}" commit old-two
check "@{-1}@{1}" commit old-one
check "@{u}" ref refs/heads/upstream-branch
check "HEAD@{u}" ref refs/heads/upstream-branch
check "@{u}@{1}" commit upstream-one
check "@{-1}@{u}" ref refs/heads/main
check "@{-1}@{u}@{1}" commit main-one
check "@" commit new-two
check "@@{u}" ref refs/heads/upstream-branch
check "@@/at-test" ref refs/heads/@@/at-test
test_have_prereq MINGW ||
check "@/at-test" ref refs/heads/@/at-test
check "@at-test" ref refs/heads/@at-test
nonsense "@{u}@{-1}"
nonsense "@{0}@{0}"
nonsense "@{1}@{u}"
nonsense "HEAD@{-1}"
nonsense "@{-1}@{-1}"

# @{N} versus HEAD@{N}

check "HEAD@{3}" commit old-two
nonsense "@{3}"

test_expect_success 'switch to old-branch' '
	shit checkout old-branch
'

check HEAD ref refs/heads/old-branch
check "HEAD@{1}" commit new-two
check "@{1}" commit old-one

test_expect_success 'create path with @' '
	echo content >normal &&
	echo content >fun@ny &&
	shit add normal fun@ny &&
	shit commit -m "funny path"
'

check "@:normal" blob content
check "@:fun@ny" blob content

test_expect_success '@{1} works with only one reflog entry' '
	shit checkout -B newbranch main &&
	shit reflog expire --expire=now refs/heads/newbranch &&
	shit commit --allow-empty -m "first after expiration" &&
	test_cmp_rev newbranch~ newbranch@{1}
'

test_expect_success '@{0} works with empty reflog' '
	shit checkout -B newbranch main &&
	shit reflog expire --expire=now refs/heads/newbranch &&
	test_cmp_rev newbranch newbranch@{0}
'

test_done
