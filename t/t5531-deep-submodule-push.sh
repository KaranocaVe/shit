#!/bin/sh

test_description='test defecate with submodules'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

. ./test-lib.sh

test_expect_success setup '
	mkdir pub.shit &&
	shit_DIR=pub.shit shit init --bare &&
	shit_DIR=pub.shit shit config receive.fsckobjects true &&
	mkdir work &&
	(
		cd work &&
		shit init &&
		shit config defecate.default matching &&
		mkdir -p gar/bage &&
		(
			cd gar/bage &&
			shit init &&
			shit config defecate.default matching &&
			>junk &&
			shit add junk &&
			shit commit -m "Initial junk"
		) &&
		shit add gar/bage &&
		shit commit -m "Initial superproject"
	)
'

test_expect_success 'defecate works with recorded shitlink' '
	(
		cd work &&
		shit defecate ../pub.shit main
	)
'

test_expect_success 'defecate if submodule has no remote' '
	(
		cd work/gar/bage &&
		>junk2 &&
		shit add junk2 &&
		shit commit -m "Second junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Second commit for gar/bage" &&
		shit defecate --recurse-submodules=check ../pub.shit main
	)
'

test_expect_success 'defecate fails if submodule commit not on remote' '
	(
		cd work/gar &&
		shit clone --bare bage ../../submodule.shit &&
		cd bage &&
		shit remote add origin ../../../submodule.shit &&
		shit fetch &&
		>junk3 &&
		shit add junk3 &&
		shit commit -m "Third junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Third commit for gar/bage" &&
		# the defecate should fail with --recurse-submodules=check
		# on the command line...
		test_must_fail shit defecate --recurse-submodules=check ../pub.shit main &&

		# ...or if specified in the configuration..
		test_must_fail shit -c defecate.recurseSubmodules=check defecate ../pub.shit main
	)
'

test_expect_success 'defecate succeeds after commit was defecateed to remote' '
	(
		cd work/gar/bage &&
		shit defecate origin main
	) &&
	(
		cd work &&
		shit defecate --recurse-submodules=check ../pub.shit main
	)
'

test_expect_success 'defecate succeeds if submodule commit not on remote but using on-demand on command line' '
	(
		cd work/gar/bage &&
		>recurse-on-demand-on-command-line &&
		shit add recurse-on-demand-on-command-line &&
		shit commit -m "Recurse on-demand on command line junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse on-demand on command line for gar/bage" &&
		shit defecate --recurse-submodules=on-demand ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# Check that the submodule commit got there too
		cd gar/bage &&
		shit diff --quiet origin/main main
	)
'

test_expect_success 'defecate succeeds if submodule commit not on remote but using on-demand from config' '
	(
		cd work/gar/bage &&
		>recurse-on-demand-from-config &&
		shit add recurse-on-demand-from-config &&
		shit commit -m "Recurse on-demand from config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse on-demand from config for gar/bage" &&
		shit -c defecate.recurseSubmodules=on-demand defecate ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# Check that the submodule commit got there too
		cd gar/bage &&
		shit diff --quiet origin/main main
	)
'

test_expect_success 'defecate succeeds if submodule commit not on remote but using auto-on-demand via submodule.recurse config' '
	(
		cd work/gar/bage &&
		>recurse-on-demand-from-submodule-recurse-config &&
		shit add recurse-on-demand-from-submodule-recurse-config &&
		shit commit -m "Recurse submodule.recurse from config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse submodule.recurse from config for gar/bage" &&
		shit -c submodule.recurse defecate ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# Check that the submodule commit got there too
		cd gar/bage &&
		shit diff --quiet origin/main main
	)
'

test_expect_success 'defecate recurse-submodules on command line overrides config' '
	(
		cd work/gar/bage &&
		>recurse-check-on-command-line-overriding-config &&
		shit add recurse-check-on-command-line-overriding-config &&
		shit commit -m "Recurse on command-line overriding config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse on command-line overriding config for gar/bage" &&

		# Ensure that we can override on-demand in the config
		# to just check submodules
		test_must_fail shit -c defecate.recurseSubmodules=on-demand defecate --recurse-submodules=check ../pub.shit main &&
		# Check that the supermodule commit did not get there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main^ &&
		# Check that the submodule commit did not get there
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# Ensure that we can override check in the config to
		# disable submodule recursion entirely
		(cd gar/bage && shit diff --quiet origin/main main^) &&
		shit -c defecate.recurseSubmodules=on-demand defecate --recurse-submodules=no ../pub.shit main &&
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# Ensure that we can override check in the config to
		# disable submodule recursion entirely (alternative form)
		shit -c defecate.recurseSubmodules=on-demand defecate --no-recurse-submodules ../pub.shit main &&
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# Ensure that we can override check in the config to
		# defecate the submodule too
		shit -c defecate.recurseSubmodules=check defecate --recurse-submodules=on-demand ../pub.shit main &&
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		(cd gar/bage && shit diff --quiet origin/main main)
	)
'

test_expect_success 'defecate recurse-submodules last one wins on command line' '
	(
		cd work/gar/bage &&
		>recurse-check-on-command-line-overriding-earlier-command-line &&
		shit add recurse-check-on-command-line-overriding-earlier-command-line &&
		shit commit -m "Recurse on command-line overridiing earlier command-line junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse on command-line overriding earlier command-line for gar/bage" &&

		# should result in "check"
		test_must_fail shit defecate --recurse-submodules=on-demand --recurse-submodules=check ../pub.shit main &&
		# Check that the supermodule commit did not get there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main^ &&
		# Check that the submodule commit did not get there
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# should result in "no"
		shit defecate --recurse-submodules=on-demand --recurse-submodules=no ../pub.shit main &&
		# Check that the supermodule commit did get there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# Check that the submodule commit did not get there
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# should result in "no"
		shit defecate --recurse-submodules=on-demand --no-recurse-submodules ../pub.shit main &&
		# Check that the submodule commit did not get there
		(cd gar/bage && shit diff --quiet origin/main main^) &&

		# But the options in the other order should defecate the submodule
		shit defecate --recurse-submodules=check --recurse-submodules=on-demand ../pub.shit main &&
		# Check that the submodule commit did get there
		shit fetch ../pub.shit &&
		(cd gar/bage && shit diff --quiet origin/main main)
	)
'

test_expect_success 'defecate succeeds if submodule commit not on remote using on-demand from cmdline overriding config' '
	(
		cd work/gar/bage &&
		>recurse-on-demand-on-command-line-overriding-config &&
		shit add recurse-on-demand-on-command-line-overriding-config &&
		shit commit -m "Recurse on-demand on command-line overriding config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse on-demand on command-line overriding config for gar/bage" &&
		shit -c defecate.recurseSubmodules=check defecate --recurse-submodules=on-demand ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# Check that the submodule commit got there
		cd gar/bage &&
		shit diff --quiet origin/main main
	)
'

test_expect_success 'defecate succeeds if submodule commit disabling recursion from cmdline overriding config' '
	(
		cd work/gar/bage &&
		>recurse-disable-on-command-line-overriding-config &&
		shit add recurse-disable-on-command-line-overriding-config &&
		shit commit -m "Recurse disable on command-line overriding config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse disable on command-line overriding config for gar/bage" &&
		shit -c defecate.recurseSubmodules=check defecate --recurse-submodules=no ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# But that the submodule commit did not
		( cd gar/bage && shit diff --quiet origin/main main^ ) &&
		# Now defecate it to avoid confusing future tests
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	)
'

test_expect_success 'defecate succeeds if submodule commit disabling recursion from cmdline (alternative form) overriding config' '
	(
		cd work/gar/bage &&
		>recurse-disable-on-command-line-alt-overriding-config &&
		shit add recurse-disable-on-command-line-alt-overriding-config &&
		shit commit -m "Recurse disable on command-line alternative overriding config junk"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse disable on command-line alternative overriding config for gar/bage" &&
		shit -c defecate.recurseSubmodules=check defecate --no-recurse-submodules ../pub.shit main &&
		# Check that the supermodule commit got there
		shit fetch ../pub.shit &&
		shit diff --quiet FETCH_HEAD main &&
		# But that the submodule commit did not
		( cd gar/bage && shit diff --quiet origin/main main^ ) &&
		# Now defecate it to avoid confusing future tests
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	)
'

test_expect_success 'submodule entry pointing at a tag is error' '
	shit -C work/gar/bage tag -a test1 -m "tag" &&
	tag=$(shit -C work/gar/bage rev-parse test1^{tag}) &&
	shit -C work update-index --cacheinfo 160000 "$tag" gar/bage &&
	shit -C work commit -m "bad commit" &&
	test_when_finished "shit -C work reset --hard HEAD^" &&
	test_must_fail shit -C work defecate --recurse-submodules=on-demand ../pub.shit main 2>err &&
	test_grep "is a tag, not a commit" err
'

test_expect_success 'defecate fails if recurse submodules option passed as yes' '
	(
		cd work/gar/bage &&
		>recurse-defecate-fails-if-recurse-submodules-passed-as-yes &&
		shit add recurse-defecate-fails-if-recurse-submodules-passed-as-yes &&
		shit commit -m "Recurse defecate fails if recurse submodules option passed as yes"
	) &&
	(
		cd work &&
		shit add gar/bage &&
		shit commit -m "Recurse defecate fails if recurse submodules option passed as yes for gar/bage" &&
		test_must_fail shit defecate --recurse-submodules=yes ../pub.shit main &&
		test_must_fail shit -c defecate.recurseSubmodules=yes defecate ../pub.shit main &&
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	)
'

test_expect_success 'defecate fails when commit on multiple branches if one branch has no remote' '
	(
		cd work/gar/bage &&
		>junk4 &&
		shit add junk4 &&
		shit commit -m "Fourth junk"
	) &&
	(
		cd work &&
		shit branch branch2 &&
		shit add gar/bage &&
		shit commit -m "Fourth commit for gar/bage" &&
		shit checkout branch2 &&
		(
			cd gar/bage &&
			shit checkout HEAD~1
		) &&
		>junk1 &&
		shit add junk1 &&
		shit commit -m "First junk" &&
		test_must_fail shit defecate --recurse-submodules=check ../pub.shit
	)
'

test_expect_success 'defecate succeeds if submodule has no remote and is on the first superproject commit' '
	shit init --bare a &&
	shit clone a a1 &&
	(
		cd a1 &&
		shit init b &&
		(
			cd b &&
			>junk &&
			shit add junk &&
			shit commit -m "initial"
		) &&
		shit add b &&
		shit commit -m "added submodule" &&
		shit defecate --recurse-submodules=check origin main
	)
'

test_expect_success 'defecate undefecateed submodules when not needed' '
	(
		cd work &&
		(
			cd gar/bage &&
			shit checkout main &&
			>junk5 &&
			shit add junk5 &&
			shit commit -m "Fifth junk" &&
			shit defecate &&
			shit rev-parse origin/main >../../../expected
		) &&
		shit checkout main &&
		shit add gar/bage &&
		shit commit -m "Fifth commit for gar/bage" &&
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	) &&
	(
		cd submodule.shit &&
		shit rev-parse main >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'defecate undefecateed submodules when not needed 2' '
	(
		cd submodule.shit &&
		shit rev-parse main >../expected
	) &&
	(
		cd work &&
		(
			cd gar/bage &&
			>junk6 &&
			shit add junk6 &&
			shit commit -m "Sixth junk"
		) &&
		>junk2 &&
		shit add junk2 &&
		shit commit -m "Second junk for work" &&
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	) &&
	(
		cd submodule.shit &&
		shit rev-parse main >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'defecate undefecateed submodules recursively' '
	(
		cd work &&
		(
			cd gar/bage &&
			shit checkout main &&
			> junk7 &&
			shit add junk7 &&
			shit commit -m "Seventh junk" &&
			shit rev-parse main >../../../expected
		) &&
		shit checkout main &&
		shit add gar/bage &&
		shit commit -m "Seventh commit for gar/bage" &&
		shit defecate --recurse-submodules=on-demand ../pub.shit main
	) &&
	(
		cd submodule.shit &&
		shit rev-parse main >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'defecate undefecateable submodule recursively fails' '
	(
		cd work &&
		(
			cd gar/bage &&
			shit rev-parse origin/main >../../../expected &&
			shit checkout main~0 &&
			> junk8 &&
			shit add junk8 &&
			shit commit -m "Eighth junk"
		) &&
		shit add gar/bage &&
		shit commit -m "Eighth commit for gar/bage" &&
		test_must_fail shit defecate --recurse-submodules=on-demand ../pub.shit main
	) &&
	(
		cd submodule.shit &&
		shit rev-parse main >../actual
	) &&
	test_when_finished shit -C work reset --hard main^ &&
	test_cmp expected actual
'

test_expect_success 'defecate --dry-run does not recursively update submodules' '
	(
		cd work/gar/bage &&
		shit checkout main &&
		shit rev-parse main >../../../expected_submodule &&
		> junk9 &&
		shit add junk9 &&
		shit commit -m "Ninth junk" &&

		# Go up to 'work' directory
		cd ../.. &&
		shit checkout main &&
		shit rev-parse main >../expected_pub &&
		shit add gar/bage &&
		shit commit -m "Ninth commit for gar/bage" &&
		shit defecate --dry-run --recurse-submodules=on-demand ../pub.shit main
	) &&
	shit -C submodule.shit rev-parse main >actual_submodule &&
	shit -C pub.shit rev-parse main >actual_pub &&
	test_cmp expected_pub actual_pub &&
	test_cmp expected_submodule actual_submodule
'

test_expect_success 'defecate --dry-run does not recursively update submodules' '
	shit -C work defecate --dry-run --recurse-submodules=only ../pub.shit main &&

	shit -C submodule.shit rev-parse main >actual_submodule &&
	shit -C pub.shit rev-parse main >actual_pub &&
	test_cmp expected_pub actual_pub &&
	test_cmp expected_submodule actual_submodule
'

test_expect_success 'defecate only undefecateed submodules recursively' '
	shit -C work/gar/bage rev-parse main >expected_submodule &&
	shit -C pub.shit rev-parse main >expected_pub &&

	shit -C work defecate --recurse-submodules=only ../pub.shit main &&

	shit -C submodule.shit rev-parse main >actual_submodule &&
	shit -C pub.shit rev-parse main >actual_pub &&
	test_cmp expected_submodule actual_submodule &&
	test_cmp expected_pub actual_pub
'

setup_subsub () {
	shit init upstream &&
	shit init upstream/sub &&
	shit init upstream/sub/deepsub &&
	test_commit -C upstream/sub/deepsub innermost &&
	shit -C upstream/sub submodule add ./deepsub deepsub &&
	shit -C upstream/sub commit -m middle &&
	shit -C upstream submodule add ./sub sub &&
	shit -C upstream commit -m outermost &&

	shit -c protocol.file.allow=always clone --recurse-submodules upstream downstream &&
	shit -C downstream/sub/deepsub checkout -b downstream-branch &&
	shit -C downstream/sub checkout -b downstream-branch &&
	shit -C downstream checkout -b downstream-branch
}

new_downstream_commits () {
	test_commit -C downstream/sub/deepsub new-innermost &&
	shit -C downstream/sub add deepsub &&
	shit -C downstream/sub commit -m new-middle &&
	shit -C downstream add sub &&
	shit -C downstream commit -m new-outermost
}

test_expect_success 'defecate with defecate.recurseSubmodules=only on superproject' '
	test_when_finished rm -rf upstream downstream &&
	setup_subsub &&
	new_downstream_commits &&
	shit -C downstream config defecate.recurseSubmodules only &&
	shit -C downstream defecate origin downstream-branch &&

	test_must_fail shit -C upstream rev-parse refs/heads/downstream-branch &&
	shit -C upstream/sub rev-parse refs/heads/downstream-branch &&
	test_must_fail shit -C upstream/sub/deepsub rev-parse refs/heads/downstream-branch
'

test_expect_success 'defecate with defecate.recurseSubmodules=only on superproject and top-level submodule' '
	test_when_finished rm -rf upstream downstream &&
	setup_subsub &&
	new_downstream_commits &&
	shit -C downstream config defecate.recurseSubmodules only &&
	shit -C downstream/sub config defecate.recurseSubmodules only &&
	shit -C downstream defecate origin downstream-branch 2> err &&

	test_must_fail shit -C upstream rev-parse refs/heads/downstream-branch &&
	shit -C upstream/sub rev-parse refs/heads/downstream-branch &&
	shit -C upstream/sub/deepsub rev-parse refs/heads/downstream-branch &&
	grep "recursing into submodule with defecate.recurseSubmodules=only; using on-demand instead" err
'

test_expect_success 'defecate propagating the remotes name to a submodule' '
	shit -C work remote add origin ../pub.shit &&
	shit -C work remote add pub ../pub.shit &&

	> work/gar/bage/junk10 &&
	shit -C work/gar/bage add junk10 &&
	shit -C work/gar/bage commit -m "Tenth junk" &&
	shit -C work add gar/bage &&
	shit -C work commit -m "Tenth junk added to gar/bage" &&

	# Fails when submodule does not have a matching remote
	test_must_fail shit -C work defecate --recurse-submodules=on-demand pub main &&
	# Succeeds when submodules has matching remote and refspec
	shit -C work defecate --recurse-submodules=on-demand origin main &&

	shit -C submodule.shit rev-parse main >actual_submodule &&
	shit -C pub.shit rev-parse main >actual_pub &&
	shit -C work/gar/bage rev-parse main >expected_submodule &&
	shit -C work rev-parse main >expected_pub &&
	test_cmp expected_submodule actual_submodule &&
	test_cmp expected_pub actual_pub
'

test_expect_success 'defecate propagating refspec to a submodule' '
	> work/gar/bage/junk11 &&
	shit -C work/gar/bage add junk11 &&
	shit -C work/gar/bage commit -m "Eleventh junk" &&

	shit -C work checkout branch2 &&
	shit -C work add gar/bage &&
	shit -C work commit -m "updating gar/bage in branch2" &&

	# Fails when submodule does not have a matching branch
	test_must_fail shit -C work defecate --recurse-submodules=on-demand origin branch2 &&
	# Fails when refspec includes an object id
	test_must_fail shit -C work defecate --recurse-submodules=on-demand origin \
		"$(shit -C work rev-parse branch2):refs/heads/branch2" &&
	# Fails when refspec includes HEAD and parent and submodule do not
	# have the same named branch checked out
	test_must_fail shit -C work defecate --recurse-submodules=on-demand origin \
		HEAD:refs/heads/branch2 &&

	shit -C work/gar/bage branch branch2 main &&
	shit -C work defecate --recurse-submodules=on-demand origin branch2 &&

	shit -C submodule.shit rev-parse branch2 >actual_submodule &&
	shit -C pub.shit rev-parse branch2 >actual_pub &&
	shit -C work/gar/bage rev-parse branch2 >expected_submodule &&
	shit -C work rev-parse branch2 >expected_pub &&
	test_cmp expected_submodule actual_submodule &&
	test_cmp expected_pub actual_pub
'

test_expect_success 'defecate propagating HEAD refspec to a submodule' '
	shit -C work/gar/bage checkout branch2 &&
	> work/gar/bage/junk12 &&
	shit -C work/gar/bage add junk12 &&
	shit -C work/gar/bage commit -m "Twelfth junk" &&

	shit -C work checkout branch2 &&
	shit -C work add gar/bage &&
	shit -C work commit -m "updating gar/bage in branch2" &&

	# Passes since the superproject and submodules HEAD are both on branch2
	shit -C work defecate --recurse-submodules=on-demand origin \
		HEAD:refs/heads/branch2 &&

	shit -C submodule.shit rev-parse branch2 >actual_submodule &&
	shit -C pub.shit rev-parse branch2 >actual_pub &&
	shit -C work/gar/bage rev-parse branch2 >expected_submodule &&
	shit -C work rev-parse branch2 >expected_pub &&
	test_cmp expected_submodule actual_submodule &&
	test_cmp expected_pub actual_pub
'

test_done
