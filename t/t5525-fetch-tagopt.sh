#!/bin/sh

test_description='tagopt variable affects "shit fetch" and is overridden by commandline.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

setup_clone () {
	shit clone --mirror . $1 &&
	shit remote add remote_$1 $1 &&
	(cd $1 &&
	shit tag tag_$1 &&
	shit branch branch_$1)
}

test_expect_success setup '
	test_commit test &&
	setup_clone one &&
	shit config remote.remote_one.tagopt --no-tags &&
	setup_clone two &&
	shit config remote.remote_two.tagopt --tags
	'

test_expect_success "fetch with tagopt=--no-tags does not get tag" '
	shit fetch remote_one &&
	test_must_fail shit show-ref tag_one &&
	shit show-ref remote_one/branch_one
	'

test_expect_success "fetch --tags with tagopt=--no-tags gets tag" '
	(
		cd one &&
		shit branch second_branch_one
	) &&
	shit fetch --tags remote_one &&
	shit show-ref tag_one &&
	shit show-ref remote_one/second_branch_one
	'

test_expect_success "fetch --no-tags with tagopt=--tags does not get tag" '
	shit fetch --no-tags remote_two &&
	test_must_fail shit show-ref tag_two &&
	shit show-ref remote_two/branch_two
	'

test_expect_success "fetch with tagopt=--tags gets tag" '
	(
		cd two &&
		shit branch second_branch_two
	) &&
	shit fetch remote_two &&
	shit show-ref tag_two &&
	shit show-ref remote_two/second_branch_two
	'
test_done
