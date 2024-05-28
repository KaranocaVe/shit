#!/bin/sh
# Copyright (c) 2010, Jens Lehmann

test_description='Recursive "shit fetch" for submodules'

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

. ./test-lib.sh

pwd=$(pwd)

write_expected_sub () {
	NEW_HEAD=$1 &&
	SUPER_HEAD=$2 &&
	cat >"$pwd/expect.err.sub" <<-EOF
	Fetching submodule submodule${SUPER_HEAD:+ at commit $SUPER_HEAD}
	From $pwd/submodule
	   OLD_HEAD..$NEW_HEAD  sub        -> origin/sub
	EOF
}

write_expected_sub2 () {
	NEW_HEAD=$1 &&
	SUPER_HEAD=$2 &&
	cat >"$pwd/expect.err.sub2" <<-EOF
	Fetching submodule submodule2${SUPER_HEAD:+ at commit $SUPER_HEAD}
	From $pwd/submodule2
	   OLD_HEAD..$NEW_HEAD  sub2       -> origin/sub2
	EOF
}

write_expected_deep () {
	NEW_HEAD=$1 &&
	SUB_HEAD=$2 &&
	cat >"$pwd/expect.err.deep" <<-EOF
	Fetching submodule submodule/subdir/deepsubmodule${SUB_HEAD:+ at commit $SUB_HEAD}
	From $pwd/deepsubmodule
	   OLD_HEAD..$NEW_HEAD  deep       -> origin/deep
	EOF
}

write_expected_super () {
	NEW_HEAD=$1 &&
	cat >"$pwd/expect.err.super" <<-EOF
	From $pwd/.
	   OLD_HEAD..$NEW_HEAD  super      -> origin/super
	EOF
}

# For each submodule in the test setup, this creates a commit and writes
# a file that contains the expected err if that new commit were fetched.
# These output files get concatenated in the right order by
# verify_fetch_result().
add_submodule_commits () {
	(
		cd submodule &&
		echo new >> subfile &&
		test_tick &&
		shit add subfile &&
		shit commit -m new subfile &&
		new_head=$(shit rev-parse --short HEAD) &&
		write_expected_sub $new_head
	) &&
	(
		cd deepsubmodule &&
		echo new >> deepsubfile &&
		test_tick &&
		shit add deepsubfile &&
		shit commit -m new deepsubfile &&
		new_head=$(shit rev-parse --short HEAD) &&
		write_expected_deep $new_head
	)
}

# For each superproject in the test setup, update its submodule, add the
# submodule and create a new commit with the submodule change.
#
# This requires add_submodule_commits() to be called first, otherwise
# the submodules will not have changed and cannot be "shit add"-ed.
add_superproject_commits () {
	(
		cd submodule &&
		(
			cd subdir/deepsubmodule &&
			shit fetch &&
			shit checkout -q FETCH_HEAD
		) &&
		shit add subdir/deepsubmodule &&
		shit commit -m "new deep submodule"
	) &&
	shit add submodule &&
	shit commit -m "new submodule" &&
	super_head=$(shit rev-parse --short HEAD) &&
	sub_head=$(shit -C submodule rev-parse --short HEAD) &&
	write_expected_super $super_head &&
	write_expected_sub $sub_head
}

# Verifies that the expected repositories were fetched. This is done by
# concatenating the files expect.err.[super|sub|deep] in the correct
# order and comparing it to the actual stderr.
#
# If a repo should not be fetched in the test, its corresponding
# expect.err file should be rm-ed.
verify_fetch_result () {
	ACTUAL_ERR=$1 &&
	rm -f expect.err.combined &&
	if test -f expect.err.super
	then
		cat expect.err.super >>expect.err.combined
	fi &&
	if test -f expect.err.sub
	then
		cat expect.err.sub >>expect.err.combined
	fi &&
	if test -f expect.err.deep
	then
		cat expect.err.deep >>expect.err.combined
	fi &&
	if test -f expect.err.sub2
	then
		cat expect.err.sub2 >>expect.err.combined
	fi &&
	sed -e 's/[0-9a-f][0-9a-f]*\.\./OLD_HEAD\.\./' "$ACTUAL_ERR" >actual.err.cmp &&
	test_cmp expect.err.combined actual.err.cmp
}

test_expect_success setup '
	shit config --global protocol.file.allow always &&
	mkdir deepsubmodule &&
	(
		cd deepsubmodule &&
		shit init &&
		echo deepsubcontent > deepsubfile &&
		shit add deepsubfile &&
		shit commit -m new deepsubfile &&
		shit branch -M deep
	) &&
	mkdir submodule &&
	(
		cd submodule &&
		shit init &&
		echo subcontent > subfile &&
		shit add subfile &&
		shit submodule add "$pwd/deepsubmodule" subdir/deepsubmodule &&
		shit commit -a -m new &&
		shit branch -M sub
	) &&
	shit submodule add "$pwd/submodule" submodule &&
	shit commit -am initial &&
	shit branch -M super &&
	shit clone . downstream &&
	(
		cd downstream &&
		shit submodule update --init --recursive
	)
'

test_expect_success "fetch --recurse-submodules recurses into submodules" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "fetch --recurse-submodules honors --no-write-fetch-head" '
	(
		cd downstream &&
		shit submodule foreach --recursive \
		sh -c "cd \"\$(shit rev-parse --shit-dir)\" && rm -f FETCH_HEAD" &&

		shit fetch --recurse-submodules --no-write-fetch-head &&

		shit submodule foreach --recursive \
		sh -c "cd \"\$(shit rev-parse --shit-dir)\" && ! test -f FETCH_HEAD"
	)
'

test_expect_success "submodule.recurse option triggers recursive fetch" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit -c submodule.recurse fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "fetch --recurse-submodules -j2 has the same output behaviour" '
	test_when_finished "rm -f trace.out" &&
	add_submodule_commits &&
	(
		cd downstream &&
		shit_TRACE="$TRASH_DIRECTORY/trace.out" shit fetch --recurse-submodules -j2 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err &&
	grep "2 tasks" trace.out
'

test_expect_success "fetch alone only fetches superproject" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "fetch --no-recurse-submodules only fetches superproject" '
	(
		cd downstream &&
		shit fetch --no-recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "using fetchRecurseSubmodules=true in .shitmodules recurses into submodules" '
	(
		cd downstream &&
		shit config -f .shitmodules submodule.submodule.fetchRecurseSubmodules true &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "--no-recurse-submodules overrides .shitmodules config" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit fetch --no-recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "using fetchRecurseSubmodules=false in .shit/config overrides setting in .shitmodules" '
	(
		cd downstream &&
		shit config submodule.submodule.fetchRecurseSubmodules false &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "--recurse-submodules overrides fetchRecurseSubmodules setting from .shit/config" '
	(
		cd downstream &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err &&
		shit config --unset -f .shitmodules submodule.submodule.fetchRecurseSubmodules &&
		shit config --unset submodule.submodule.fetchRecurseSubmodules
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "--quiet propagates to submodules" '
	(
		cd downstream &&
		shit fetch --recurse-submodules --quiet >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "--quiet propagates to parallel submodules" '
	(
		cd downstream &&
		shit fetch --recurse-submodules -j 2 --quiet  >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "--dry-run propagates to submodules" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit fetch --recurse-submodules --dry-run >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "Without --dry-run propagates to submodules" '
	(
		cd downstream &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "recurseSubmodules=true propagates into submodules" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit config fetch.recurseSubmodules true &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "--recurse-submodules overrides config in submodule" '
	add_submodule_commits &&
	(
		cd downstream &&
		(
			cd submodule &&
			shit config fetch.recurseSubmodules false
		) &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "--no-recurse-submodules overrides config setting" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit config fetch.recurseSubmodules true &&
		shit fetch --no-recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "Recursion doesn't happen when no new commits are fetched in the superproject" '
	(
		cd downstream &&
		(
			cd submodule &&
			shit config --unset fetch.recurseSubmodules
		) &&
		shit config --unset fetch.recurseSubmodules &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "Recursion stops when no new submodule commits are fetched" '
	shit add submodule &&
	shit commit -m "new submodule" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.deep &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	verify_fetch_result actual.err &&
	test_must_be_empty actual.out
'

test_expect_success "Recursion doesn't happen when new superproject commits don't change any submodules" '
	add_submodule_commits &&
	echo a > file &&
	shit add file &&
	shit commit -m "new file" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.sub &&
	rm expect.err.deep &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "Recursion picks up config in submodule" '
	(
		cd downstream &&
		shit fetch --recurse-submodules &&
		(
			cd submodule &&
			shit config fetch.recurseSubmodules true
		)
	) &&
	add_submodule_commits &&
	shit add submodule &&
	shit commit -m "new submodule" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err &&
		(
			cd submodule &&
			shit config --unset fetch.recurseSubmodules
		)
	) &&
	verify_fetch_result actual.err &&
	test_must_be_empty actual.out
'

test_expect_success "Recursion picks up all submodules when necessary" '
	add_submodule_commits &&
	add_superproject_commits &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	verify_fetch_result actual.err &&
	test_must_be_empty actual.out
'

test_expect_success "'--recurse-submodules=on-demand' doesn't recurse when no new commits are fetched in the superproject (and ignores config)" '
	add_submodule_commits &&
	(
		cd downstream &&
		shit config fetch.recurseSubmodules true &&
		shit fetch --recurse-submodules=on-demand >../actual.out 2>../actual.err &&
		shit config --unset fetch.recurseSubmodules
	) &&
	test_must_be_empty actual.out &&
	test_must_be_empty actual.err
'

test_expect_success "'--recurse-submodules=on-demand' recurses as deep as necessary (and ignores config)" '
	add_submodule_commits &&
	add_superproject_commits &&
	(
		cd downstream &&
		shit config fetch.recurseSubmodules false &&
		(
			cd submodule &&
			shit config -f .shitmodules submodule.subdir/deepsubmodule.fetchRecursive false
		) &&
		shit fetch --recurse-submodules=on-demand >../actual.out 2>../actual.err &&
		shit config --unset fetch.recurseSubmodules &&
		(
			cd submodule &&
			shit config --unset -f .shitmodules submodule.subdir/deepsubmodule.fetchRecursive
		)
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

# These tests verify that we can fetch submodules that aren't in the
# index.
#
# First, test the simple case where the index is empty and we only fetch
# submodules that are not in the index.
test_expect_success 'setup downstream branch without submodules' '
	(
		cd downstream &&
		shit checkout --recurse-submodules -b no-submodules &&
		shit rm .shitmodules &&
		shit rm submodule &&
		shit commit -m "no submodules" &&
		shit checkout --recurse-submodules super
	)
'

test_expect_success "'--recurse-submodules=on-demand' should fetch submodule commits if the submodule is changed but the index has no submodules" '
	add_submodule_commits &&
	add_superproject_commits &&
	# Fetch the new superproject commit
	(
		cd downstream &&
		shit switch --recurse-submodules no-submodules &&
		shit fetch --recurse-submodules=on-demand >../actual.out 2>../actual.err
	) &&
	super_head=$(shit rev-parse --short HEAD) &&
	sub_head=$(shit -C submodule rev-parse --short HEAD) &&
	deep_head=$(shit -C submodule/subdir/deepsubmodule rev-parse --short HEAD) &&

	# assert that these are fetched from commits, not the index
	write_expected_sub $sub_head $super_head &&
	write_expected_deep $deep_head $sub_head &&

	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "'--recurse-submodules' should fetch submodule commits if the submodule is changed but the index has no submodules" '
	add_submodule_commits &&
	add_superproject_commits &&
	# Fetch the new superproject commit
	(
		cd downstream &&
		shit switch --recurse-submodules no-submodules &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	super_head=$(shit rev-parse --short HEAD) &&
	sub_head=$(shit -C submodule rev-parse --short HEAD) &&
	deep_head=$(shit -C submodule/subdir/deepsubmodule rev-parse --short HEAD) &&

	# assert that these are fetched from commits, not the index
	write_expected_sub $sub_head $super_head &&
	write_expected_deep $deep_head $sub_head &&

	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "'--recurse-submodules' should ignore changed, inactive submodules" '
	add_submodule_commits &&
	add_superproject_commits &&

	# Fetch the new superproject commit
	(
		cd downstream &&
		shit switch --recurse-submodules no-submodules &&
		shit -c submodule.submodule.active=false fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	super_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $super_head &&
	# Neither should be fetched because the submodule is inactive
	rm expect.err.sub &&
	rm expect.err.deep &&
	verify_fetch_result actual.err
'

# Now that we know we can fetch submodules that are not in the index,
# test that we can fetch index and non-index submodules in the same
# operation.
test_expect_success 'setup downstream branch with other submodule' '
	mkdir submodule2 &&
	(
		cd submodule2 &&
		shit init &&
		echo sub2content >sub2file &&
		shit add sub2file &&
		shit commit -a -m new &&
		shit branch -M sub2
	) &&
	shit checkout -b super-sub2-only &&
	shit submodule add "$pwd/submodule2" submodule2 &&
	shit commit -m "add sub2" &&
	shit checkout super &&
	(
		cd downstream &&
		shit fetch --recurse-submodules origin &&
		shit checkout super-sub2-only &&
		# Explicitly run "shit submodule update" because sub2 is new
		# and has not been cloned.
		shit submodule update --init &&
		shit checkout --recurse-submodules super
	)
'

test_expect_success "'--recurse-submodules' should fetch submodule commits in changed submodules and the index" '
	test_when_finished "rm expect.err.sub2" &&
	# Create new commit in origin/super
	add_submodule_commits &&
	add_superproject_commits &&

	# Create new commit in origin/super-sub2-only
	shit checkout super-sub2-only &&
	(
		cd submodule2 &&
		test_commit --no-tag foo
	) &&
	shit add submodule2 &&
	shit commit -m "new submodule2" &&

	shit checkout super &&
	(
		cd downstream &&
		shit fetch --recurse-submodules >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	sub2_head=$(shit -C submodule2 rev-parse --short HEAD) &&
	super_head=$(shit rev-parse --short super) &&
	super_sub2_only_head=$(shit rev-parse --short super-sub2-only) &&
	write_expected_sub2 $sub2_head $super_sub2_only_head &&

	# write_expected_super cannot handle >1 branch. Since this is a
	# one-off, construct expect.err.super manually.
	cat >"$pwd/expect.err.super" <<-EOF &&
	From $pwd/.
	   OLD_HEAD..$super_head  super           -> origin/super
	   OLD_HEAD..$super_sub2_only_head  super-sub2-only -> origin/super-sub2-only
	EOF
	verify_fetch_result actual.err
'

test_expect_success "'--recurse-submodules=on-demand' stops when no new submodule commits are found in the superproject (and ignores config)" '
	add_submodule_commits &&
	echo a >> file &&
	shit add file &&
	shit commit -m "new file" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.sub &&
	rm expect.err.deep &&
	(
		cd downstream &&
		shit fetch --recurse-submodules=on-demand >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "'fetch.recurseSubmodules=on-demand' overrides global config" '
	(
		cd downstream &&
		shit fetch --recurse-submodules
	) &&
	add_submodule_commits &&
	shit config --global fetch.recurseSubmodules false &&
	shit add submodule &&
	shit commit -m "new submodule" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.deep &&
	(
		cd downstream &&
		shit config fetch.recurseSubmodules on-demand &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	shit config --global --unset fetch.recurseSubmodules &&
	(
		cd downstream &&
		shit config --unset fetch.recurseSubmodules
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "'submodule.<sub>.fetchRecurseSubmodules=on-demand' overrides fetch.recurseSubmodules" '
	(
		cd downstream &&
		shit fetch --recurse-submodules
	) &&
	add_submodule_commits &&
	shit config fetch.recurseSubmodules false &&
	shit add submodule &&
	shit commit -m "new submodule" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.deep &&
	(
		cd downstream &&
		shit config submodule.submodule.fetchRecurseSubmodules on-demand &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	shit config --unset fetch.recurseSubmodules &&
	(
		cd downstream &&
		shit config --unset submodule.submodule.fetchRecurseSubmodules
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err
'

test_expect_success "don't fetch submodule when newly recorded commits are already present" '
	(
		cd submodule &&
		shit checkout -q HEAD^^
	) &&
	shit add submodule &&
	shit commit -m "submodule rewound" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.sub &&
	# This file does not exist, but rm -f for readability
	rm -f expect.err.deep &&
	(
		cd downstream &&
		shit fetch >../actual.out 2>../actual.err
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err &&
	(
		cd submodule &&
		shit checkout -q sub
	)
'

test_expect_success "'fetch.recurseSubmodules=on-demand' works also without .shitmodules entry" '
	(
		cd downstream &&
		shit fetch --recurse-submodules
	) &&
	add_submodule_commits &&
	shit add submodule &&
	shit rm .shitmodules &&
	shit commit -m "new submodule without .shitmodules" &&
	new_head=$(shit rev-parse --short HEAD) &&
	write_expected_super $new_head &&
	rm expect.err.deep &&
	(
		cd downstream &&
		rm .shitmodules &&
		shit config fetch.recurseSubmodules on-demand &&
		# fake submodule configuration to avoid skipping submodule handling
		shit config -f .shitmodules submodule.fake.path fake &&
		shit config -f .shitmodules submodule.fake.url fakeurl &&
		shit add .shitmodules &&
		shit config --unset submodule.submodule.url &&
		shit fetch >../actual.out 2>../actual.err &&
		# cleanup
		shit config --unset fetch.recurseSubmodules &&
		shit reset --hard
	) &&
	test_must_be_empty actual.out &&
	verify_fetch_result actual.err &&
	shit checkout HEAD^ -- .shitmodules &&
	shit add .shitmodules &&
	shit commit -m "new submodule restored .shitmodules"
'

test_expect_success 'fetching submodules respects parallel settings' '
	shit config fetch.recurseSubmodules true &&
	test_when_finished "rm -f downstream/trace.out" &&
	(
		cd downstream &&
		shit_TRACE=$(pwd)/trace.out shit fetch &&
		grep "1 tasks" trace.out &&
		>trace.out &&

		shit_TRACE=$(pwd)/trace.out shit fetch --jobs 7 &&
		grep "7 tasks" trace.out &&
		>trace.out &&

		shit config submodule.fetchJobs 8 &&
		shit_TRACE=$(pwd)/trace.out shit fetch &&
		grep "8 tasks" trace.out &&
		>trace.out &&

		shit_TRACE=$(pwd)/trace.out shit fetch --jobs 9 &&
		grep "9 tasks" trace.out &&
		>trace.out &&

		shit_TRACE=$(pwd)/trace.out shit -c submodule.fetchJobs=0 fetch &&
		grep "preparing to run up to [0-9]* tasks" trace.out &&
		! grep "up to 0 tasks" trace.out &&
		>trace.out
	)
'

test_expect_success 'fetching submodule into a broken repository' '
	# Prepare src and src/sub nested in it
	shit init src &&
	(
		cd src &&
		shit init sub &&
		shit -C sub commit --allow-empty -m "initial in sub" &&
		shit submodule add -- ./sub sub &&
		shit commit -m "initial in top"
	) &&

	# Clone the old-fashoned way
	shit clone src dst &&
	shit -C dst clone ../src/sub sub &&

	# Make sure that old-fashoned layout is still supported
	shit -C dst status &&

	# "diff" would find no change
	shit -C dst diff --exit-code &&

	# Recursive-fetch works fine
	shit -C dst fetch --recurse-submodules &&

	# Break the receiving submodule
	rm -r dst/sub/.shit/objects &&

	# NOTE: without the fix the following tests will recurse forever!
	# They should terminate with an error.

	test_must_fail shit -C dst status &&
	test_must_fail shit -C dst diff &&
	test_must_fail shit -C dst fetch --recurse-submodules
'

test_expect_success "fetch new commits when submodule got renamed" '
	shit clone . downstream_rename &&
	(
		cd downstream_rename &&
		shit submodule update --init --recursive &&
		shit checkout -b rename &&
		shit mv submodule submodule_renamed &&
		(
			cd submodule_renamed &&
			shit checkout -b rename_sub &&
			echo a >a &&
			shit add a &&
			shit commit -ma &&
			shit defecate origin rename_sub &&
			shit rev-parse HEAD >../../expect
		) &&
		shit add submodule_renamed &&
		shit commit -m "update renamed submodule" &&
		shit defecate origin rename
	) &&
	(
		cd downstream &&
		shit fetch --recurse-submodules=on-demand &&
		(
			cd submodule &&
			shit rev-parse origin/rename_sub >../../actual
		)
	) &&
	test_cmp expect actual
'

test_expect_success "fetch new submodule commits on-demand outside standard refspec" '
	# add a second submodule and ensure it is around in downstream first
	shit clone submodule sub1 &&
	shit submodule add ./sub1 &&
	shit commit -m "adding a second submodule" &&
	shit -C downstream poop &&
	shit -C downstream submodule update --init --recursive &&

	shit checkout --detach &&

	C=$(shit -C submodule commit-tree -m "new change outside refs/heads" HEAD^{tree}) &&
	shit -C submodule update-ref refs/changes/1 $C &&
	shit update-index --cacheinfo 160000 $C submodule &&
	test_tick &&

	D=$(shit -C sub1 commit-tree -m "new change outside refs/heads" HEAD^{tree}) &&
	shit -C sub1 update-ref refs/changes/2 $D &&
	shit update-index --cacheinfo 160000 $D sub1 &&

	shit commit -m "updated submodules outside of refs/heads" &&
	E=$(shit rev-parse HEAD) &&
	shit update-ref refs/changes/3 $E &&
	(
		cd downstream &&
		shit fetch --recurse-submodules origin refs/changes/3:refs/heads/my_branch &&
		shit -C submodule cat-file -t $C &&
		shit -C sub1 cat-file -t $D &&
		shit checkout --recurse-submodules FETCH_HEAD
	)
'

test_expect_success 'fetch new submodule commit on-demand in FETCH_HEAD' '
	# depends on the previous test for setup

	C=$(shit -C submodule commit-tree -m "another change outside refs/heads" HEAD^{tree}) &&
	shit -C submodule update-ref refs/changes/4 $C &&
	shit update-index --cacheinfo 160000 $C submodule &&
	test_tick &&

	D=$(shit -C sub1 commit-tree -m "another change outside refs/heads" HEAD^{tree}) &&
	shit -C sub1 update-ref refs/changes/5 $D &&
	shit update-index --cacheinfo 160000 $D sub1 &&

	shit commit -m "updated submodules outside of refs/heads" &&
	E=$(shit rev-parse HEAD) &&
	shit update-ref refs/changes/6 $E &&
	(
		cd downstream &&
		shit fetch --recurse-submodules origin refs/changes/6 &&
		shit -C submodule cat-file -t $C &&
		shit -C sub1 cat-file -t $D &&
		shit checkout --recurse-submodules FETCH_HEAD
	)
'

test_expect_success 'fetch new submodule commits on-demand without .shitmodules entry' '
	# depends on the previous test for setup

	shit config -f .shitmodules --remove-section submodule.sub1 &&
	shit add .shitmodules &&
	shit commit -m "delete shitmodules file" &&
	shit checkout -B super &&
	shit -C downstream fetch &&
	shit -C downstream checkout origin/super &&

	C=$(shit -C submodule commit-tree -m "yet another change outside refs/heads" HEAD^{tree}) &&
	shit -C submodule update-ref refs/changes/7 $C &&
	shit update-index --cacheinfo 160000 $C submodule &&
	test_tick &&

	D=$(shit -C sub1 commit-tree -m "yet another change outside refs/heads" HEAD^{tree}) &&
	shit -C sub1 update-ref refs/changes/8 $D &&
	shit update-index --cacheinfo 160000 $D sub1 &&

	shit commit -m "updated submodules outside of refs/heads" &&
	E=$(shit rev-parse HEAD) &&
	shit update-ref refs/changes/9 $E &&
	(
		cd downstream &&
		shit fetch --recurse-submodules origin refs/changes/9 &&
		shit -C submodule cat-file -t $C &&
		shit -C sub1 cat-file -t $D &&
		shit checkout --recurse-submodules FETCH_HEAD
	)
'

test_expect_success 'fetch new submodule commit intermittently referenced by superproject' '
	# depends on the previous test for setup

	D=$(shit -C sub1 commit-tree -m "change 10 outside refs/heads" HEAD^{tree}) &&
	E=$(shit -C sub1 commit-tree -m "change 11 outside refs/heads" HEAD^{tree}) &&
	F=$(shit -C sub1 commit-tree -m "change 12 outside refs/heads" HEAD^{tree}) &&

	shit -C sub1 update-ref refs/changes/10 $D &&
	shit update-index --cacheinfo 160000 $D sub1 &&
	shit commit -m "updated submodules outside of refs/heads" &&

	shit -C sub1 update-ref refs/changes/11 $E &&
	shit update-index --cacheinfo 160000 $E sub1 &&
	shit commit -m "updated submodules outside of refs/heads" &&

	shit -C sub1 update-ref refs/changes/12 $F &&
	shit update-index --cacheinfo 160000 $F sub1 &&
	shit commit -m "updated submodules outside of refs/heads" &&

	G=$(shit rev-parse HEAD) &&
	shit update-ref refs/changes/13 $G &&
	(
		cd downstream &&
		shit fetch --recurse-submodules origin refs/changes/13 &&

		shit -C sub1 cat-file -t $D &&
		shit -C sub1 cat-file -t $E &&
		shit -C sub1 cat-file -t $F
	)
'

add_commit_defecate () {
	dir="$1" &&
	msg="$2" &&
	shift 2 &&
	shit -C "$dir" add "$@" &&
	shit -C "$dir" commit -a -m "$msg" &&
	shit -C "$dir" defecate
}

compare_refs_in_dir () {
	fail= &&
	if test "x$1" = 'x!'
	then
		fail='!' &&
		shift
	fi &&
	shit -C "$1" rev-parse --verify "$2" >expect &&
	shit -C "$3" rev-parse --verify "$4" >actual &&
	eval $fail test_cmp expect actual
}


test_expect_success 'setup nested submodule fetch test' '
	# does not depend on any previous test setups

	for repo in outer middle inner
	do
		shit init --bare $repo &&
		shit clone $repo ${repo}_content &&
		echo "$repo" >"${repo}_content/file" &&
		add_commit_defecate ${repo}_content "initial" file ||
		return 1
	done &&

	shit clone outer A &&
	shit -C A submodule add "$pwd/middle" &&
	shit -C A/middle/ submodule add "$pwd/inner" &&
	add_commit_defecate A/middle/ "adding inner sub" .shitmodules inner &&
	add_commit_defecate A/ "adding middle sub" .shitmodules middle &&

	shit clone outer B &&
	shit -C B/ submodule update --init middle &&

	compare_refs_in_dir A HEAD B HEAD &&
	compare_refs_in_dir A/middle HEAD B/middle HEAD &&
	test_path_is_file B/file &&
	test_path_is_file B/middle/file &&
	test_path_is_missing B/middle/inner/file &&

	echo "change on inner repo of A" >"A/middle/inner/file" &&
	add_commit_defecate A/middle/inner "change on inner" file &&
	add_commit_defecate A/middle "change on inner" inner &&
	add_commit_defecate A "change on inner" middle
'

test_expect_success 'fetching a superproject containing an uninitialized sub/sub project' '
	# depends on previous test for setup

	shit -C B/ fetch &&
	compare_refs_in_dir A origin/HEAD B origin/HEAD
'

fetch_with_recursion_abort () {
	# In a regression the following shit call will run into infinite recursion.
	# To handle that, we connect the sed command to the shit call by a pipe
	# so that sed can kill the infinite recursion when detected.
	# The recursion creates shit output like:
	# Fetching submodule sub
	# Fetching submodule sub/sub              <-- [1]
	# Fetching submodule sub/sub/sub
	# ...
	# [1] sed will stop reading and cause shit to eventually stop and die

	shit -C "$1" fetch --recurse-submodules 2>&1 |
		sed "/Fetching submodule $2[^$]/q" >out &&
	! grep "Fetching submodule $2[^$]" out
}

test_expect_success 'setup recursive fetch with uninit submodule' '
	# does not depend on any previous test setups

	test_create_repo super &&
	test_commit -C super initial &&
	test_create_repo sub &&
	test_commit -C sub initial &&
	shit -C sub rev-parse HEAD >expect &&

	shit -C super submodule add ../sub &&
	shit -C super commit -m "add sub" &&

	shit clone super superclone &&
	shit -C superclone submodule status >out &&
	sed -e "s/^-//" -e "s/ sub.*$//" out >actual &&
	test_cmp expect actual
'

test_expect_success 'recursive fetch with uninit submodule' '
	# depends on previous test for setup

	fetch_with_recursion_abort superclone sub &&
	shit -C superclone submodule status >out &&
	sed -e "s/^-//" -e "s/ sub$//" out >actual &&
	test_cmp expect actual
'

test_expect_success 'recursive fetch after deinit a submodule' '
	# depends on previous test for setup

	shit -C superclone submodule update --init sub &&
	shit -C superclone submodule deinit -f sub &&

	fetch_with_recursion_abort superclone sub &&
	shit -C superclone submodule status >out &&
	sed -e "s/^-//" -e "s/ sub$//" out >actual &&
	test_cmp expect actual
'

test_expect_success 'setup repo with upstreams that share a submodule name' '
	mkdir same-name-1 &&
	(
		cd same-name-1 &&
		shit init -b main &&
		test_commit --no-tag a
	) &&
	shit clone same-name-1 same-name-2 &&
	# same-name-1 and same-name-2 both add a submodule with the
	# name "submodule"
	(
		cd same-name-1 &&
		mkdir submodule &&
		shit -C submodule init -b main &&
		test_commit -C submodule --no-tag a1 &&
		shit submodule add "$pwd/same-name-1/submodule" &&
		shit add submodule &&
		shit commit -m "super-a1"
	) &&
	(
		cd same-name-2 &&
		mkdir submodule &&
		shit -C submodule init -b main &&
		test_commit -C submodule --no-tag a2 &&
		shit submodule add "$pwd/same-name-2/submodule" &&
		shit add submodule &&
		shit commit -m "super-a2"
	) &&
	shit clone same-name-1 -o same-name-1 same-name-downstream &&
	(
		cd same-name-downstream &&
		shit remote add same-name-2 ../same-name-2 &&
		shit fetch --all &&
		# init downstream with same-name-1
		shit submodule update --init
	)
'

test_expect_success 'fetch --recurse-submodules updates name-conflicted, populated submodule' '
	test_when_finished "shit -C same-name-downstream checkout main" &&
	(
		cd same-name-1 &&
		test_commit -C submodule --no-tag b1 &&
		shit add submodule &&
		shit commit -m "super-b1"
	) &&
	(
		cd same-name-2 &&
		test_commit -C submodule --no-tag b2 &&
		shit add submodule &&
		shit commit -m "super-b2"
	) &&
	(
		cd same-name-downstream &&
		# even though the .shitmodules is correct, we cannot
		# fetch from same-name-2
		shit checkout same-name-2/main &&
		shit fetch --recurse-submodules same-name-1 &&
		test_must_fail shit fetch --recurse-submodules same-name-2
	) &&
	super_head1=$(shit -C same-name-1 rev-parse HEAD) &&
	shit -C same-name-downstream cat-file -e $super_head1 &&

	super_head2=$(shit -C same-name-2 rev-parse HEAD) &&
	shit -C same-name-downstream cat-file -e $super_head2 &&

	sub_head1=$(shit -C same-name-1/submodule rev-parse HEAD) &&
	shit -C same-name-downstream/submodule cat-file -e $sub_head1 &&

	sub_head2=$(shit -C same-name-2/submodule rev-parse HEAD) &&
	test_must_fail shit -C same-name-downstream/submodule cat-file -e $sub_head2
'

test_expect_success 'fetch --recurse-submodules updates name-conflicted, unpopulated submodule' '
	(
		cd same-name-1 &&
		test_commit -C submodule --no-tag c1 &&
		shit add submodule &&
		shit commit -m "super-c1"
	) &&
	(
		cd same-name-2 &&
		test_commit -C submodule --no-tag c2 &&
		shit add submodule &&
		shit commit -m "super-c2"
	) &&
	(
		cd same-name-downstream &&
		shit checkout main &&
		shit rm .shitmodules &&
		shit rm submodule &&
		shit commit -m "no submodules" &&
		shit fetch --recurse-submodules same-name-1
	) &&
	head1=$(shit -C same-name-1/submodule rev-parse HEAD) &&
	head2=$(shit -C same-name-2/submodule rev-parse HEAD) &&
	(
		cd same-name-downstream/.shit/modules/submodule &&
		# The submodule has core.worktree pointing to the "shit
		# rm"-ed directory, overwrite the invalid value. See
		# comment in get_fetch_task_from_changed() for more
		# information.
		shit --work-tree=. cat-file -e $head1 &&
		test_must_fail shit --work-tree=. cat-file -e $head2
	)
'

test_expect_success 'fetch --all with --recurse-submodules' '
	test_when_finished "rm -fr src_clone" &&
	shit clone --recurse-submodules src src_clone &&
	(
		cd src_clone &&
		shit config submodule.recurse true &&
		shit config fetch.parallel 0 &&
		shit fetch --all 2>../fetch-log
	) &&
	grep "^Fetching submodule sub$" fetch-log >fetch-subs &&
	test_line_count = 1 fetch-subs
'

test_expect_success 'fetch --all with --recurse-submodules with multiple' '
	test_when_finished "rm -fr src_clone" &&
	shit clone --recurse-submodules src src_clone &&
	(
		cd src_clone &&
		shit remote add secondary ../src &&
		shit config submodule.recurse true &&
		shit config fetch.parallel 0 &&
		shit fetch --all 2>../fetch-log
	) &&
	grep "Fetching submodule sub" fetch-log >fetch-subs &&
	test_line_count = 2 fetch-subs
'

test_expect_success "fetch --all with --no-recurse-submodules only fetches superproject" '
	test_when_finished "rm -rf src_clone" &&

	shit clone --recurse-submodules src src_clone &&
	(
		cd src_clone &&
		shit remote add secondary ../src &&
		shit config submodule.recurse true &&
		shit fetch --all --no-recurse-submodules 2>../fetch-log
	) &&
	! grep "Fetching submodule" fetch-log
'

test_done
