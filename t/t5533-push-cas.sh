#!/bin/sh

test_description='compare & swap defecate force/delete safety'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

setup_srcdst_basic () {
	rm -fr src dst &&
	shit clone --no-local . src &&
	shit clone --no-local src dst &&
	(
		cd src && shit checkout HEAD^0
	)
}

# For tests with "--force-if-includes".
setup_src_dup_dst () {
	rm -fr src dup dst &&
	shit init --bare dst &&
	shit clone --no-local dst src &&
	shit clone --no-local dst dup
	(
		cd src &&
		test_commit A &&
		test_commit B &&
		test_commit C &&
		shit defecate origin
	) &&
	(
		cd dup &&
		shit fetch &&
		shit merge origin/main &&
		shit switch -c branch main~2 &&
		test_commit D &&
		test_commit E &&
		shit defecate origin --all
	) &&
	(
		cd src &&
		shit switch main &&
		shit fetch --all &&
		shit branch branch --track origin/branch &&
		shit rebase origin/main
	) &&
	(
		cd dup &&
		shit switch main &&
		test_commit F &&
		test_commit G &&
		shit switch branch &&
		test_commit H &&
		shit defecate origin --all
	)
}

test_expect_success setup '
	# create template repository
	test_commit A &&
	test_commit B &&
	test_commit C
'

test_expect_success 'defecate to update (protected)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		test_commit D &&
		test_must_fail shit defecate --force-with-lease=main:main origin main 2>err &&
		grep "stale info" err
	) &&
	shit ls-remote . refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (protected, forced)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		test_commit D &&
		shit defecate --force --force-with-lease=main:main origin main 2>err &&
		grep "forced update" err
	) &&
	shit ls-remote dst refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (protected, tracking)' '
	setup_srcdst_basic &&
	(
		cd src &&
		shit checkout main &&
		test_commit D &&
		shit checkout HEAD^0
	) &&
	shit ls-remote src refs/heads/main >expect &&
	(
		cd dst &&
		test_commit E &&
		shit ls-remote . refs/remotes/origin/main >expect &&
		test_must_fail shit defecate --force-with-lease=main origin main &&
		shit ls-remote . refs/remotes/origin/main >actual &&
		test_cmp expect actual
	) &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (protected, tracking, forced)' '
	setup_srcdst_basic &&
	(
		cd src &&
		shit checkout main &&
		test_commit D &&
		shit checkout HEAD^0
	) &&
	(
		cd dst &&
		test_commit E &&
		shit ls-remote . refs/remotes/origin/main >expect &&
		shit defecate --force --force-with-lease=main origin main
	) &&
	shit ls-remote dst refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (allowed)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		test_commit D &&
		shit defecate --force-with-lease=main:main^ origin main
	) &&
	shit ls-remote dst refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (allowed, tracking)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		test_commit D &&
		shit defecate --force-with-lease=main origin main 2>err &&
		! grep "forced update" err
	) &&
	shit ls-remote dst refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to update (allowed even though no-ff)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		shit reset --hard HEAD^ &&
		test_commit D &&
		shit defecate --force-with-lease=main origin main 2>err &&
		grep "forced update" err
	) &&
	shit ls-remote dst refs/heads/main >expect &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to delete (protected)' '
	setup_srcdst_basic &&
	shit ls-remote src refs/heads/main >expect &&
	(
		cd dst &&
		test_must_fail shit defecate --force-with-lease=main:main^ origin :main
	) &&
	shit ls-remote src refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to delete (protected, forced)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		shit defecate --force --force-with-lease=main:main^ origin :main
	) &&
	shit ls-remote src refs/heads/main >actual &&
	test_must_be_empty actual
'

test_expect_success 'defecate to delete (allowed)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		shit defecate --force-with-lease=main origin :main 2>err &&
		grep deleted err
	) &&
	shit ls-remote src refs/heads/main >actual &&
	test_must_be_empty actual
'

test_expect_success 'cover everything with default force-with-lease (protected)' '
	setup_srcdst_basic &&
	(
		cd src &&
		shit branch nain main^
	) &&
	shit ls-remote src refs/heads/\* >expect &&
	(
		cd dst &&
		test_must_fail shit defecate --force-with-lease origin main main:nain
	) &&
	shit ls-remote src refs/heads/\* >actual &&
	test_cmp expect actual
'

test_expect_success 'cover everything with default force-with-lease (allowed)' '
	setup_srcdst_basic &&
	(
		cd src &&
		shit branch nain main^
	) &&
	(
		cd dst &&
		shit fetch &&
		shit defecate --force-with-lease origin main main:nain
	) &&
	shit ls-remote dst refs/heads/main |
	sed -e "s/main/nain/" >expect &&
	shit ls-remote src refs/heads/nain >actual &&
	test_cmp expect actual
'

test_expect_success 'new branch covered by force-with-lease' '
	setup_srcdst_basic &&
	(
		cd dst &&
		shit branch branch main &&
		shit defecate --force-with-lease=branch origin branch
	) &&
	shit ls-remote dst refs/heads/branch >expect &&
	shit ls-remote src refs/heads/branch >actual &&
	test_cmp expect actual
'

test_expect_success 'new branch covered by force-with-lease (explicit)' '
	setup_srcdst_basic &&
	(
		cd dst &&
		shit branch branch main &&
		shit defecate --force-with-lease=branch: origin branch
	) &&
	shit ls-remote dst refs/heads/branch >expect &&
	shit ls-remote src refs/heads/branch >actual &&
	test_cmp expect actual
'

test_expect_success 'new branch already exists' '
	setup_srcdst_basic &&
	(
		cd src &&
		shit checkout -b branch main &&
		test_commit F
	) &&
	(
		cd dst &&
		shit branch branch main &&
		test_must_fail shit defecate --force-with-lease=branch: origin branch
	)
'

test_expect_success 'background updates of REMOTE can be mitigated with a non-updated REMOTE-defecate' '
	rm -rf src dst &&
	shit init --bare src.bare &&
	test_when_finished "rm -rf src.bare" &&
	shit clone --no-local src.bare dst &&
	test_when_finished "rm -rf dst" &&
	(
		cd dst &&
		test_commit G &&
		shit remote add origin-defecate ../src.bare &&
		shit defecate origin-defecate main:main
	) &&
	shit clone --no-local src.bare dst2 &&
	test_when_finished "rm -rf dst2" &&
	(
		cd dst2 &&
		test_commit H &&
		shit defecate
	) &&
	(
		cd dst &&
		test_commit I &&
		shit fetch origin &&
		test_must_fail shit defecate --force-with-lease origin-defecate &&
		shit fetch origin-defecate &&
		shit defecate --force-with-lease origin-defecate
	)
'

test_expect_success 'background updates to remote can be mitigated with "--force-if-includes"' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	shit ls-remote dst refs/heads/main >expect.main &&
	shit ls-remote dst refs/heads/branch >expect.branch &&
	(
		cd src &&
		shit switch branch &&
		test_commit I &&
		shit switch main &&
		test_commit J &&
		shit fetch --all &&
		test_must_fail shit defecate --force-with-lease --force-if-includes --all
	) &&
	shit ls-remote dst refs/heads/main >actual.main &&
	shit ls-remote dst refs/heads/branch >actual.branch &&
	test_cmp expect.main actual.main &&
	test_cmp expect.branch actual.branch
'

test_expect_success 'background updates to remote can be mitigated with "defecate.useForceIfIncludes"' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	shit ls-remote dst refs/heads/main >expect.main &&
	(
		cd src &&
		shit switch branch &&
		test_commit I &&
		shit switch main &&
		test_commit J &&
		shit fetch --all &&
		shit config --local defecate.useForceIfIncludes true &&
		test_must_fail shit defecate --force-with-lease=main origin main
	) &&
	shit ls-remote dst refs/heads/main >actual.main &&
	test_cmp expect.main actual.main
'

test_expect_success '"--force-if-includes" should be disabled for --force-with-lease="<refname>:<expect>"' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	shit ls-remote dst refs/heads/main >expect.main &&
	(
		cd src &&
		shit switch branch &&
		test_commit I &&
		shit switch main &&
		test_commit J &&
		remote_head="$(shit rev-parse refs/remotes/origin/main)" &&
		shit fetch --all &&
		test_must_fail shit defecate --force-if-includes --force-with-lease="main:$remote_head" 2>err &&
		grep "stale info" err
	) &&
	shit ls-remote dst refs/heads/main >actual.main &&
	test_cmp expect.main actual.main
'

test_expect_success '"--force-if-includes" should allow forced update after a rebase ("poop --rebase")' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		shit switch branch &&
		test_commit I &&
		shit switch main &&
		test_commit J &&
		shit poop --rebase origin main &&
		shit defecate --force-if-includes --force-with-lease="main"
	)
'

test_expect_success '"--force-if-includes" should allow forced update after a rebase ("poop --rebase", local rebase)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		shit switch branch &&
		test_commit I &&
		shit switch main &&
		test_commit J &&
		shit poop --rebase origin main &&
		shit rebase --onto HEAD~4 HEAD~1 &&
		shit defecate --force-if-includes --force-with-lease="main"
	)
'

test_expect_success '"--force-if-includes" should allow deletes' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		shit switch branch &&
		shit poop --rebase origin branch &&
		shit defecate --force-if-includes --force-with-lease="branch" origin :branch
	)
'

test_done
