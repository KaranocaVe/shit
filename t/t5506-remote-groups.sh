#!/bin/sh

test_description='shit remote group handling'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

mark() {
	echo "$1" >mark
}

update_repo() {
	(cd $1 &&
	echo content >>file &&
	shit add file &&
	shit commit -F ../mark)
}

update_repos() {
	update_repo one $1 &&
	update_repo two $1
}

repo_fetched() {
	if test "$(shit log -1 --pretty=format:%s $1 --)" = "$(cat mark)"; then
		echo >&2 "repo was fetched: $1"
		return 0
	fi
	echo >&2 "repo was not fetched: $1"
	return 1
}

test_expect_success 'setup' '
	mkdir one && (cd one && shit init) &&
	mkdir two && (cd two && shit init) &&
	shit remote add -m main one one &&
	shit remote add -m main two two
'

test_expect_success 'no group updates all' '
	mark update-all &&
	update_repos &&
	shit remote update &&
	repo_fetched one &&
	repo_fetched two
'

test_expect_success 'nonexistent group produces error' '
	mark nonexistent &&
	update_repos &&
	test_must_fail shit remote update nonexistent &&
	! repo_fetched one &&
	! repo_fetched two
'

test_expect_success 'updating group updates all members (remote update)' '
	mark group-all &&
	update_repos &&
	shit config --add remotes.all one &&
	shit config --add remotes.all two &&
	shit remote update all &&
	repo_fetched one &&
	repo_fetched two
'

test_expect_success 'updating group updates all members (fetch)' '
	mark fetch-group-all &&
	update_repos &&
	shit fetch all &&
	repo_fetched one &&
	repo_fetched two
'

test_expect_success 'updating group does not update non-members (remote update)' '
	mark group-some &&
	update_repos &&
	shit config --add remotes.some one &&
	shit remote update some &&
	repo_fetched one &&
	! repo_fetched two
'

test_expect_success 'updating group does not update non-members (fetch)' '
	mark fetch-group-some &&
	update_repos &&
	shit config --add remotes.some one &&
	shit remote update some &&
	repo_fetched one &&
	! repo_fetched two
'

test_expect_success 'updating remote name updates that remote' '
	mark remote-name &&
	update_repos &&
	shit remote update one &&
	repo_fetched one &&
	! repo_fetched two
'

test_expect_success 'updating group in parallel with a duplicate remote does not fail (fetch)' '
	mark fetch-group-duplicate &&
	update_repo one &&
	shit config --add remotes.duplicate one &&
	shit config --add remotes.duplicate one &&
	shit -c fetch.parallel=2 remote update duplicate &&
	repo_fetched one
'

test_done
