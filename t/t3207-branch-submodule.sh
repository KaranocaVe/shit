#!/bin/sh

test_description='shit branch submodule tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

pwd=$(pwd)

# Creates a clean test environment in "pwd" by copying the repo setup
# from test_dirs.
reset_test () {
	rm -fr super &&
	rm -fr sub-sub-upstream &&
	rm -fr sub-upstream &&
	cp -r test_dirs/* .
}

# Tests that the expected branch does not exist
test_no_branch () {
	DIR=$1 &&
	BRANCH_NAME=$2 &&
	test_must_fail shit -C "$DIR" rev-parse "$BRANCH_NAME" 2>err &&
	grep "ambiguous argument .$BRANCH_NAME." err
}

test_expect_success 'setup superproject and submodule' '
	shit config --global protocol.file.allow always &&
	mkdir test_dirs &&
	(
		cd test_dirs &&
		shit init super &&
		test_commit -C super foo &&
		shit init sub-sub-upstream &&
		test_commit -C sub-sub-upstream foo &&
		shit init sub-upstream &&
		# Submodule in a submodule
		shit -C sub-upstream submodule add "${pwd}/test_dirs/sub-sub-upstream" sub-sub &&
		shit -C sub-upstream commit -m "add submodule" &&
		# Regular submodule
		shit -C super submodule add "${pwd}/test_dirs/sub-upstream" sub &&
		# Submodule in a subdirectory
		shit -C super submodule add "${pwd}/test_dirs/sub-sub-upstream" second/sub &&
		shit -C super commit -m "add submodule" &&
		shit -C super config submodule.propagateBranches true &&
		shit -C super/sub submodule update --init
	) &&
	reset_test
'

# Test the argument parsing
test_expect_success '--recurse-submodules should create branches' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a &&
		shit rev-parse branch-a &&
		shit -C sub rev-parse branch-a &&
		shit -C sub/sub-sub rev-parse branch-a &&
		shit -C second/sub rev-parse branch-a
	)
'

test_expect_success '--recurse-submodules should die if submodule.propagateBranches is false' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		echo "fatal: branch with --recurse-submodules can only be used if submodule.propagateBranches is enabled" >expected &&
		test_must_fail shit -c submodule.propagateBranches=false branch --recurse-submodules branch-a 2>actual &&
		test_cmp expected actual
	)
'

test_expect_success '--recurse-submodules should fail when not creating branches' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a &&
		echo "fatal: --recurse-submodules can only be used to create branches" >expected &&
		test_must_fail shit branch --recurse-submodules -D branch-a 2>actual &&
		test_cmp expected actual &&
		# Assert that the branches were not deleted
		shit rev-parse branch-a &&
		shit -C sub rev-parse branch-a
	)
'

test_expect_success 'should respect submodule.recurse when creating branches' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit -c submodule.recurse=true branch branch-a &&
		shit rev-parse branch-a &&
		shit -C sub rev-parse branch-a
	)
'

test_expect_success 'should ignore submodule.recurse when not creating branches' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a &&
		shit -c submodule.recurse=true branch -D branch-a &&
		test_no_branch . branch-a &&
		shit -C sub rev-parse branch-a
	)
'

# Test branch creation behavior
test_expect_success 'should create branches based off commit id in superproject' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a &&
		shit checkout --recurse-submodules branch-a &&
		shit -C sub rev-parse HEAD >expected &&
		# Move the tip of sub:branch-a so that it no longer matches the commit in super:branch-a
		shit -C sub checkout branch-a &&
		test_commit -C sub bar &&
		# Create a new branch-b branch with start-point=branch-a
		shit branch --recurse-submodules branch-b branch-a &&
		shit rev-parse branch-b &&
		shit -C sub rev-parse branch-b >actual &&
		# Assert that the commit id of sub:second-branch matches super:branch-a and not sub:branch-a
		test_cmp expected actual
	)
'

test_expect_success 'should not create any branches if branch is not valid for all repos' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit -C sub branch branch-a &&
		test_must_fail shit branch --recurse-submodules branch-a 2>actual &&
		test_no_branch . branch-a &&
		grep "submodule .sub.: fatal: a branch named .branch-a. already exists" actual
	)
'

test_expect_success 'should create branches if branch exists and --force is given' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit -C sub rev-parse HEAD >expected &&
		test_commit -C sub baz &&
		# branch-a in sub now points to a newer commit.
		shit -C sub branch branch-a HEAD &&
		shit -C sub rev-parse branch-a >actual-old-branch-a &&
		shit branch --recurse-submodules --force branch-a &&
		shit rev-parse branch-a &&
		shit -C sub rev-parse branch-a >actual-new-branch-a &&
		test_cmp expected actual-new-branch-a &&
		# assert that branch --force actually moved the sub
		# branch
		! test_cmp expected actual-old-branch-a
	)
'

test_expect_success 'should create branch when submodule is not in HEAD:.shitmodules' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch branch-a &&
		shit checkout -b branch-b &&
		shit submodule add ../sub-upstream sub2 &&
		shit -C sub2 submodule update --init &&
		# branch-b now has a committed submodule not in branch-a
		shit commit -m "add second submodule" &&
		shit checkout branch-a &&
		shit branch --recurse-submodules branch-c branch-b &&
		shit checkout --recurse-submodules branch-c &&
		shit -C sub2 rev-parse branch-c &&
		shit -C sub2/sub-sub rev-parse branch-c
	)
'

test_expect_success 'should not create branches in inactive submodules' '
	test_when_finished "reset_test" &&
	test_config -C super submodule.sub.active false &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a &&
		shit rev-parse branch-a &&
		test_no_branch sub branch-a
	)
'

test_expect_success 'should set up tracking of local branches with track=always' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit -c branch.autoSetupMerge=always branch --recurse-submodules branch-a main &&
		shit -C sub rev-parse main &&
		test_cmp_config -C sub . branch.branch-a.remote &&
		test_cmp_config -C sub refs/heads/main branch.branch-a.merge
	)
'

test_expect_success 'should set up tracking of local branches with explicit track' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --track --recurse-submodules branch-a main &&
		shit -C sub rev-parse main &&
		test_cmp_config -C sub . branch.branch-a.remote &&
		test_cmp_config -C sub refs/heads/main branch.branch-a.merge
	)
'

test_expect_success 'should not set up unnecessary tracking of local branches' '
	test_when_finished "reset_test" &&
	(
		cd super &&
		shit branch --recurse-submodules branch-a main &&
		shit -C sub rev-parse main &&
		test_cmp_config -C sub "" --default "" branch.branch-a.remote &&
		test_cmp_config -C sub "" --default "" branch.branch-a.merge
	)
'

reset_remote_test () {
	rm -fr super-clone &&
	reset_test
}

test_expect_success 'setup tests with remotes' '
	(
		cd test_dirs &&
		(
			cd super &&
			shit branch branch-a &&
			shit checkout -b branch-b &&
			shit submodule add ../sub-upstream sub2 &&
			# branch-b now has a committed submodule not in branch-a
			shit commit -m "add second submodule"
		) &&
		shit clone --branch main --recurse-submodules super super-clone &&
		shit -C super-clone config submodule.propagateBranches true
	) &&
	reset_remote_test
'

test_expect_success 'should get fatal error upon branch creation when submodule is not in .shit/modules' '
	test_when_finished "reset_remote_test" &&
	(
		cd super-clone &&
		# This should succeed because super-clone has sub in .shit/modules
		shit branch --recurse-submodules branch-a origin/branch-a &&
		# This should fail because super-clone does not have sub2 .shit/modules
		test_must_fail shit branch --recurse-submodules branch-b origin/branch-b 2>actual &&
		grep "fatal: submodule .sub2.: unable to find submodule" actual &&
		test_no_branch . branch-b &&
		test_no_branch sub branch-b &&
		# User can fix themselves by initializing the submodule
		shit checkout origin/branch-b &&
		shit submodule update --init --recursive &&
		shit branch --recurse-submodules branch-b origin/branch-b
	)
'

test_expect_success 'should set up tracking of remote-tracking branches by default' '
	test_when_finished "reset_remote_test" &&
	(
		cd super-clone &&
		shit branch --recurse-submodules branch-a origin/branch-a &&
		test_cmp_config origin branch.branch-a.remote &&
		test_cmp_config refs/heads/branch-a branch.branch-a.merge &&
		# "origin/branch-a" does not exist for "sub", but it matches the refspec
		# so tracking should be set up
		test_cmp_config -C sub origin branch.branch-a.remote &&
		test_cmp_config -C sub refs/heads/branch-a branch.branch-a.merge &&
		test_cmp_config -C sub/sub-sub origin branch.branch-a.remote &&
		test_cmp_config -C sub/sub-sub refs/heads/branch-a branch.branch-a.merge
	)
'

test_expect_success 'should not fail when unable to set up tracking in submodule' '
	test_when_finished "reset_remote_test" &&
	(
		cd super-clone &&
		shit remote rename origin ex-origin &&
		shit branch --recurse-submodules branch-a ex-origin/branch-a &&
		test_cmp_config ex-origin branch.branch-a.remote &&
		test_cmp_config refs/heads/branch-a branch.branch-a.merge &&
		test_cmp_config -C sub "" --default "" branch.branch-a.remote &&
		test_cmp_config -C sub "" --default "" branch.branch-a.merge
	)
'

test_expect_success '--track=inherit should set up tracking correctly' '
	test_when_finished "reset_remote_test" &&
	(
		cd super-clone &&
		shit branch --recurse-submodules branch-a origin/branch-a &&
		# Set this manually instead of using branch --set-upstream-to
		# to circumvent the "nonexistent upstream" check.
		shit -C sub config branch.branch-a.remote origin &&
		shit -C sub config branch.branch-a.merge refs/heads/sub-branch-a &&
		shit -C sub/sub-sub config branch.branch-a.remote other &&
		shit -C sub/sub-sub config branch.branch-a.merge refs/heads/sub-sub-branch-a &&

		shit branch --recurse-submodules --track=inherit branch-b branch-a &&
		test_cmp_config origin branch.branch-b.remote &&
		test_cmp_config refs/heads/branch-a branch.branch-b.merge &&
		test_cmp_config -C sub origin branch.branch-b.remote &&
		test_cmp_config -C sub refs/heads/sub-branch-a branch.branch-b.merge &&
		test_cmp_config -C sub/sub-sub other branch.branch-b.remote &&
		test_cmp_config -C sub/sub-sub refs/heads/sub-sub-branch-a branch.branch-b.merge
	)
'

test_expect_success '--no-track should not set up tracking' '
	test_when_finished "reset_remote_test" &&
	(
		cd super-clone &&
		shit branch --recurse-submodules --no-track branch-a origin/branch-a &&
		test_cmp_config "" --default "" branch.branch-a.remote &&
		test_cmp_config "" --default "" branch.branch-a.merge &&
		test_cmp_config -C sub "" --default "" branch.branch-a.remote &&
		test_cmp_config -C sub "" --default "" branch.branch-a.merge &&
		test_cmp_config -C sub/sub-sub "" --default "" branch.branch-a.remote &&
		test_cmp_config -C sub/sub-sub "" --default "" branch.branch-a.merge
	)
'

test_done
