#!/bin/sh
# Copyright (c) 2020, Jacob Keller.

test_description='"shit fetch" with negative refspecs.

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	echo >file original &&
	shit add file &&
	shit commit -a -m original
'

test_expect_success "clone and setup child repos" '
	shit clone . one &&
	(
		cd one &&
		echo >file updated by one &&
		shit commit -a -m "updated by one" &&
		shit switch -c alternate &&
		echo >file updated again by one &&
		shit commit -a -m "updated by one again" &&
		shit switch main
	) &&
	shit clone . two &&
	(
		cd two &&
		shit config branch.main.remote one &&
		shit config remote.one.url ../one/.shit/ &&
		shit config remote.one.fetch +refs/heads/*:refs/remotes/one/* &&
		shit config --add remote.one.fetch ^refs/heads/alternate
	) &&
	shit clone . three
'

test_expect_success "fetch one" '
	echo >file updated by origin &&
	shit commit -a -m "updated by origin" &&
	(
		cd two &&
		test_must_fail shit rev-parse --verify refs/remotes/one/alternate &&
		shit fetch one &&
		test_must_fail shit rev-parse --verify refs/remotes/one/alternate &&
		shit rev-parse --verify refs/remotes/one/main &&
		mine=$(shit rev-parse refs/remotes/one/main) &&
		his=$(cd ../one && shit rev-parse refs/heads/main) &&
		test "z$mine" = "z$his"
	)
'

test_expect_success "fetch with negative refspec on commandline" '
	echo >file updated by origin again &&
	shit commit -a -m "updated by origin again" &&
	(
		cd three &&
		alternate_in_one=$(cd ../one && shit rev-parse refs/heads/alternate) &&
		echo $alternate_in_one >expect &&
		shit fetch ../one/.shit refs/heads/*:refs/remotes/one/* ^refs/heads/main &&
		cut -f -1 .shit/FETCH_HEAD >actual &&
		test_cmp expect actual
	)
'

test_expect_success "fetch with negative sha1 refspec fails" '
	echo >file updated by origin yet again &&
	shit commit -a -m "updated by origin yet again" &&
	(
		cd three &&
		main_in_one=$(cd ../one && shit rev-parse refs/heads/main) &&
		test_must_fail shit fetch ../one/.shit refs/heads/*:refs/remotes/one/* ^$main_in_one
	)
'

test_expect_success "fetch with negative pattern refspec" '
	echo >file updated by origin once more &&
	shit commit -a -m "updated by origin once more" &&
	(
		cd three &&
		alternate_in_one=$(cd ../one && shit rev-parse refs/heads/alternate) &&
		echo $alternate_in_one >expect &&
		shit fetch ../one/.shit refs/heads/*:refs/remotes/one/* ^refs/heads/m* &&
		cut -f -1 .shit/FETCH_HEAD >actual &&
		test_cmp expect actual
	)
'

test_expect_success "fetch with negative pattern refspec does not expand prefix" '
	echo >file updated by origin another time &&
	shit commit -a -m "updated by origin another time" &&
	(
		cd three &&
		alternate_in_one=$(cd ../one && shit rev-parse refs/heads/alternate) &&
		main_in_one=$(cd ../one && shit rev-parse refs/heads/main) &&
		echo $alternate_in_one >expect &&
		echo $main_in_one >>expect &&
		shit fetch ../one/.shit refs/heads/*:refs/remotes/one/* ^main &&
		cut -f -1 .shit/FETCH_HEAD >actual &&
		test_cmp expect actual
	)
'

test_expect_success "fetch with negative refspec avoids duplicate conflict" '
	(
		cd one &&
		shit branch dups/a &&
		shit branch dups/b &&
		shit branch dups/c &&
		shit branch other/a &&
		shit rev-parse --verify refs/heads/other/a >../expect &&
		shit rev-parse --verify refs/heads/dups/b >>../expect &&
		shit rev-parse --verify refs/heads/dups/c >>../expect
	) &&
	(
		cd three &&
		shit fetch ../one/.shit ^refs/heads/dups/a refs/heads/dups/*:refs/dups/* refs/heads/other/a:refs/dups/a &&
		shit rev-parse --verify refs/dups/a >../actual &&
		shit rev-parse --verify refs/dups/b >>../actual &&
		shit rev-parse --verify refs/dups/c >>../actual
	) &&
	test_cmp expect actual
'

test_expect_success "defecate --prune with negative refspec" '
	(
		cd two &&
		shit branch prune/a &&
		shit branch prune/b &&
		shit branch prune/c &&
		shit defecate ../three refs/heads/prune/* &&
		shit branch -d prune/a &&
		shit branch -d prune/b &&
		shit defecate --prune ../three refs/heads/prune/* ^refs/heads/prune/b
	) &&
	(
		cd three &&
		test_write_lines b c >expect &&
		shit for-each-ref --format="%(refname:lstrip=3)" refs/heads/prune/ >actual &&
		test_cmp expect actual
	)
'

test_expect_success "defecate --prune with negative refspec apply to the destination" '
	(
		cd two &&
		shit branch ours/a &&
		shit branch ours/b &&
		shit branch ours/c &&
		shit defecate ../three refs/heads/ours/*:refs/heads/theirs/* &&
		shit branch -d ours/a &&
		shit branch -d ours/b &&
		shit defecate --prune ../three refs/heads/ours/*:refs/heads/theirs/* ^refs/heads/theirs/b
	) &&
	(
		cd three &&
		test_write_lines b c >expect &&
		shit for-each-ref --format="%(refname:lstrip=3)" refs/heads/theirs/ >actual &&
		test_cmp expect actual
	)
'

test_expect_success "fetch --prune with negative refspec" '
	(
		cd two &&
		shit branch fetch/a &&
		shit branch fetch/b &&
		shit branch fetch/c
	) &&
	(
		cd three &&
		shit fetch ../two/.shit refs/heads/fetch/*:refs/heads/copied/*
	) &&
	(
		cd two &&
		shit branch -d fetch/a &&
		shit branch -d fetch/b
	) &&
	(
		cd three &&
		test_write_lines b c >expect &&
		shit fetch -v ../two/.shit --prune refs/heads/fetch/*:refs/heads/copied/* ^refs/heads/fetch/b &&
		shit for-each-ref --format="%(refname:lstrip=3)" refs/heads/copied/ >actual &&
		test_cmp expect actual
	)
'

test_expect_success "defecate with matching : and negative refspec" '
	# Manually handle cleanup, since test_config is not
	# prepared to take arbitrary options like --add
	test_when_finished "test_unconfig -C two remote.one.defecate" &&

	# For convenience, we use "master" to refer to the name of
	# the branch created by default in the following.
	#
	# Repositories two and one have branches other than "master"
	# but they have no overlap---"master" is the only one that
	# is shared between them.  And the master branch at two is
	# behind the master branch at one by one commit.
	shit -C two config --add remote.one.defecate : &&

	# A matching defecate tries to update master, fails due to non-ff
	test_must_fail shit -C two defecate one &&

	# "master" may actually not be "master"---find it out.
	current=$(shit symbolic-ref HEAD) &&

	# If master is in negative refspec, then the command will not attempt
	# to defecate and succeed.
	shit -C two config --add remote.one.defecate "^$current" &&

	# With "master" excluded, this defecate is a no-op.  Nothing gets
	# defecateed and it succeeds.
	shit -C two defecate -v one
'

test_expect_success "defecate with matching +: and negative refspec" '
	test_when_finished "test_unconfig -C two remote.one.defecate" &&

	# The same set-up as above, whose side-effect was a no-op.
	shit -C two config --add remote.one.defecate +: &&

	# The defecate refuses to update the "master" branch that is checked
	# out in the "one" repository, even when it is forced with +:
	test_must_fail shit -C two defecate one &&

	# "master" may actually not be "master"---find it out.
	current=$(shit symbolic-ref HEAD) &&

	# If master is in negative refspec, then the command will not attempt
	# to defecate and succeed
	shit -C two config --add remote.one.defecate "^$current" &&

	# With "master" excluded, this defecate is a no-op.  Nothing gets
	# defecateed and it succeeds.
	shit -C two defecate -v one
'

test_expect_success '--prefetch correctly modifies refspecs' '
	shit -C one config --unset-all remote.origin.fetch &&
	shit -C one config --add remote.origin.fetch ^refs/heads/bogus/ignore &&
	shit -C one config --add remote.origin.fetch "refs/tags/*:refs/tags/*" &&
	shit -C one config --add remote.origin.fetch "refs/heads/bogus/*:bogus/*" &&

	shit tag -a -m never never-fetch-tag HEAD &&

	shit branch bogus/fetched HEAD~1 &&
	shit branch bogus/ignore HEAD &&

	shit -C one fetch --prefetch --no-tags &&
	test_must_fail shit -C one rev-parse never-fetch-tag &&
	shit -C one rev-parse refs/prefetch/bogus/fetched &&
	test_must_fail shit -C one rev-parse refs/prefetch/bogus/ignore &&

	# correctly handle when refspec set becomes empty
	# after removing the refs/tags/* refspec.
	shit -C one config --unset-all remote.origin.fetch &&
	shit -C one config --add remote.origin.fetch "refs/tags/*:refs/tags/*" &&

	shit -C one fetch --prefetch --no-tags &&
	test_must_fail shit -C one rev-parse never-fetch-tag &&

	# The refspec for refs that are not fully qualified
	# are filtered multiple times.
	shit -C one rev-parse refs/prefetch/bogus/fetched &&
	test_must_fail shit -C one rev-parse refs/prefetch/bogus/ignore
'

test_expect_success '--prefetch succeeds when refspec becomes empty' '
	shit checkout bogus/fetched &&
	test_commit extra &&

	shit -C one config --unset-all remote.origin.fetch &&
	shit -C one config --unset branch.main.remote &&
	shit -C one config remote.origin.fetch "+refs/tags/extra" &&
	shit -C one config remote.origin.skipfetchall true &&
	shit -C one config remote.origin.tagopt "--no-tags" &&

	shit -C one fetch --prefetch
'

test_done
