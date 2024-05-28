#!/bin/sh

test_description='defecateing to a mirror repository'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

D=$(pwd)

invert () {
	if "$@"; then
		return 1
	else
		return 0
	fi
}

mk_repo_pair () {
	rm -rf main mirror &&
	mkdir mirror &&
	(
		cd mirror &&
		shit init &&
		shit config receive.denyCurrentBranch warn
	) &&
	mkdir main &&
	(
		cd main &&
		shit init &&
		shit remote add $1 up ../mirror
	)
}


# BRANCH tests
test_expect_success 'defecate mirror creates new branches' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/heads/main) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/heads/main) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror updates existing branches' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit defecate --mirror up &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/heads/main) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/heads/main) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror force updates existing branches' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit defecate --mirror up &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit defecate --mirror up &&
		shit reset --hard HEAD^ &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/heads/main) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/heads/main) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror removes branches' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit branch remove main &&
		shit defecate --mirror up &&
		shit branch -D remove &&
		shit defecate --mirror up
	) &&
	(
		cd mirror &&
		invert shit show-ref -s --verify refs/heads/remove
	)

'

test_expect_success 'defecate mirror adds, updates and removes branches together' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit branch remove main &&
		shit defecate --mirror up &&
		shit branch -D remove &&
		shit branch add main &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/heads/main) &&
	main_add=$(cd main && shit show-ref -s --verify refs/heads/add) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/heads/main) &&
	mirror_add=$(cd mirror && shit show-ref -s --verify refs/heads/add) &&
	test "$main_main" = "$mirror_main" &&
	test "$main_add" = "$mirror_add" &&
	(
		cd mirror &&
		invert shit show-ref -s --verify refs/heads/remove
	)

'


# TAG tests
test_expect_success 'defecate mirror creates new tags' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit tag -f tmain main &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/tags/tmain) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/tags/tmain) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror updates existing tags' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit tag -f tmain main &&
		shit defecate --mirror up &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit tag -f tmain main &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/tags/tmain) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/tags/tmain) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror force updates existing tags' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit tag -f tmain main &&
		shit defecate --mirror up &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit tag -f tmain main &&
		shit defecate --mirror up &&
		shit reset --hard HEAD^ &&
		shit tag -f tmain main &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/tags/tmain) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/tags/tmain) &&
	test "$main_main" = "$mirror_main"

'

test_expect_success 'defecate mirror removes tags' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit tag -f tremove main &&
		shit defecate --mirror up &&
		shit tag -d tremove &&
		shit defecate --mirror up
	) &&
	(
		cd mirror &&
		invert shit show-ref -s --verify refs/tags/tremove
	)

'

test_expect_success 'defecate mirror adds, updates and removes tags together' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit tag -f tmain main &&
		shit tag -f tremove main &&
		shit defecate --mirror up &&
		shit tag -d tremove &&
		shit tag tadd main &&
		echo two >foo && shit add foo && shit commit -m two &&
		shit tag -f tmain main &&
		shit defecate --mirror up
	) &&
	main_main=$(cd main && shit show-ref -s --verify refs/tags/tmain) &&
	main_add=$(cd main && shit show-ref -s --verify refs/tags/tadd) &&
	mirror_main=$(cd mirror && shit show-ref -s --verify refs/tags/tmain) &&
	mirror_add=$(cd mirror && shit show-ref -s --verify refs/tags/tadd) &&
	test "$main_main" = "$mirror_main" &&
	test "$main_add" = "$mirror_add" &&
	(
		cd mirror &&
		invert shit show-ref -s --verify refs/tags/tremove
	)

'

test_expect_success 'remote.foo.mirror adds and removes branches' '

	mk_repo_pair --mirror &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit branch keep main &&
		shit branch remove main &&
		shit defecate up &&
		shit branch -D remove &&
		shit defecate up
	) &&
	(
		cd mirror &&
		shit show-ref -s --verify refs/heads/keep &&
		invert shit show-ref -s --verify refs/heads/remove
	)

'

test_expect_success 'remote.foo.mirror=no has no effect' '

	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit config --add remote.up.mirror no &&
		shit branch keep main &&
		shit defecate --mirror up &&
		shit branch -D keep &&
		shit defecate up :
	) &&
	(
		cd mirror &&
		shit show-ref -s --verify refs/heads/keep
	)

'

test_expect_success 'defecate to mirrored repository with refspec fails' '
	mk_repo_pair &&
	(
		cd main &&
		echo one >foo && shit add foo && shit commit -m one &&
		shit config --add remote.up.mirror true &&
		test_must_fail shit defecate up main
	)
'

test_done
