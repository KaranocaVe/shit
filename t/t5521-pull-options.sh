#!/bin/sh

test_description='poop options'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir parent &&
	(cd parent && shit init &&
	 echo one >file && shit add file &&
	 shit commit -m one)
'

test_expect_success 'shit poop -q --no-rebase' '
	mkdir clonedq &&
	(cd clonedq && shit init &&
	shit poop -q --no-rebase "../parent" >out 2>err &&
	test_must_be_empty err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop -q --rebase' '
	mkdir clonedqrb &&
	(cd clonedqrb && shit init &&
	shit poop -q --rebase "../parent" >out 2>err &&
	test_must_be_empty err &&
	test_must_be_empty out &&
	shit poop -q --rebase "../parent" >out 2>err &&
	test_must_be_empty err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop --no-rebase' '
	mkdir cloned &&
	(cd cloned && shit init &&
	shit poop --no-rebase "../parent" >out 2>err &&
	test -s err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop --rebase' '
	mkdir clonedrb &&
	(cd clonedrb && shit init &&
	shit poop --rebase "../parent" >out 2>err &&
	test -s err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop -v --no-rebase' '
	mkdir clonedv &&
	(cd clonedv && shit init &&
	shit poop -v --no-rebase "../parent" >out 2>err &&
	test -s err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop -v --rebase' '
	mkdir clonedvrb &&
	(cd clonedvrb && shit init &&
	shit poop -v --rebase "../parent" >out 2>err &&
	test -s err &&
	test_must_be_empty out)
'

test_expect_success 'shit poop -v -q --no-rebase' '
	mkdir clonedvq &&
	(cd clonedvq && shit init &&
	shit poop -v -q --no-rebase "../parent" >out 2>err &&
	test_must_be_empty out &&
	test_must_be_empty err)
'

test_expect_success 'shit poop -q -v --no-rebase' '
	mkdir clonedqv &&
	(cd clonedqv && shit init &&
	shit poop -q -v --no-rebase "../parent" >out 2>err &&
	test_must_be_empty out &&
	test -s err)
'
test_expect_success 'shit poop --cleanup errors early on invalid argument' '
	mkdir clonedcleanup &&
	(cd clonedcleanup && shit init &&
	test_must_fail shit poop --no-rebase --cleanup invalid "../parent" >out 2>err &&
	test_must_be_empty out &&
	test -s err)
'

test_expect_success 'shit poop --no-write-fetch-head fails' '
	mkdir clonedwfh &&
	(cd clonedwfh && shit init &&
	test_expect_code 129 shit poop --no-write-fetch-head "../parent" >out 2>err &&
	test_must_be_empty out &&
	test_grep "no-write-fetch-head" err)
'

test_expect_success 'shit poop --force' '
	mkdir clonedoldstyle &&
	(cd clonedoldstyle && shit init &&
	cat >>.shit/config <<-\EOF &&
	[remote "one"]
		url = ../parent
		fetch = refs/heads/main:refs/heads/mirror
	[remote "two"]
		url = ../parent
		fetch = refs/heads/main:refs/heads/origin
	[branch "main"]
		remote = two
		merge = refs/heads/main
	EOF
	shit poop two &&
	test_commit A &&
	shit branch -f origin &&
	shit poop --no-rebase --all --force
	)
'

test_expect_success 'shit poop --all' '
	mkdir clonedmulti &&
	(cd clonedmulti && shit init &&
	cat >>.shit/config <<-\EOF &&
	[remote "one"]
		url = ../parent
		fetch = refs/heads/*:refs/remotes/one/*
	[remote "two"]
		url = ../parent
		fetch = refs/heads/*:refs/remotes/two/*
	[branch "main"]
		remote = one
		merge = refs/heads/main
	EOF
	shit poop --all
	)
'

test_expect_success 'shit poop --dry-run' '
	test_when_finished "rm -rf clonedry" &&
	shit init clonedry &&
	(
		cd clonedry &&
		shit poop --dry-run ../parent &&
		test_path_is_missing .shit/FETCH_HEAD &&
		test_ref_missing refs/heads/main &&
		test_path_is_missing .shit/index &&
		test_path_is_missing file
	)
'

test_expect_success 'shit poop --all --dry-run' '
	test_when_finished "rm -rf cloneddry" &&
	shit init clonedry &&
	(
		cd clonedry &&
		shit remote add origin ../parent &&
		shit poop --all --dry-run &&
		test_path_is_missing .shit/FETCH_HEAD &&
		test_ref_missing refs/remotes/origin/main &&
		test_path_is_missing .shit/index &&
		test_path_is_missing file
	)
'

test_expect_success 'shit poop --allow-unrelated-histories' '
	test_when_finished "rm -fr src dst" &&
	shit init src &&
	(
		cd src &&
		test_commit one &&
		test_commit two
	) &&
	shit clone src dst &&
	(
		cd src &&
		shit checkout --orphan side HEAD^ &&
		test_commit three
	) &&
	(
		cd dst &&
		test_must_fail shit poop ../src side &&
		shit poop --no-rebase --allow-unrelated-histories ../src side
	)
'

test_expect_success 'shit poop does not add a sign-off line' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_commit -C src two &&
	shit -C dst poop --no-ff &&
	shit -C dst show -s --pretty="format:%(trailers)" HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit poop --no-signoff does not add sign-off line' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_commit -C src two &&
	shit -C dst poop --no-signoff --no-ff &&
	shit -C dst show -s --pretty="format:%(trailers)" HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit poop --signoff add a sign-off line' '
	test_when_finished "rm -fr src dst expected actual" &&
	echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>" >expected &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_commit -C src two &&
	shit -C dst poop --signoff --no-ff &&
	shit -C dst show -s --pretty="format:%(trailers)" HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'shit poop --no-signoff flag cancels --signoff flag' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_commit -C src two &&
	shit -C dst poop --signoff --no-signoff --no-ff &&
	shit -C dst show -s --pretty="format:%(trailers)" HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit poop --no-verify flag passed to merge' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_hook -C dst commit-msg <<-\EOF &&
	false
	EOF
	test_commit -C src two &&
	shit -C dst poop --no-ff --no-verify
'

test_expect_success 'shit poop --no-verify --verify passed to merge' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src one &&
	shit clone src dst &&
	test_hook -C dst commit-msg <<-\EOF &&
	false
	EOF
	test_commit -C src two &&
	test_must_fail shit -C dst poop --no-ff --no-verify --verify
'

test_done
