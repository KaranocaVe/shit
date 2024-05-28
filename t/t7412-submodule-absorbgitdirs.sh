#!/bin/sh

test_description='Test submodule absorbshitdirs

This test verifies that `shit submodue absorbshitdirs` moves a submodules shit
directory into the superproject.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup a real submodule' '
	cwd="$(pwd)" &&
	shit init sub1 &&
	test_commit -C sub1 first &&
	shit submodule add ./sub1 &&
	test_tick &&
	shit commit -m superproject
'

test_expect_success 'absorb the shit dir' '
	>expect &&
	>actual &&
	>expect.1 &&
	>expect.2 &&
	>actual.1 &&
	>actual.2 &&
	shit status >expect.1 &&
	shit -C sub1 rev-parse HEAD >expect.2 &&
	cat >expect <<-EOF &&
	Migrating shit directory of '\''sub1'\'' from
	'\''$cwd/sub1/.shit'\'' to
	'\''$cwd/.shit/modules/sub1'\''
	EOF
	shit submodule absorbshitdirs 2>actual &&
	test_cmp expect actual &&
	shit fsck &&
	test -f sub1/.shit &&
	test -d .shit/modules/sub1 &&
	shit status >actual.1 &&
	shit -C sub1 rev-parse HEAD >actual.2 &&
	test_cmp expect.1 actual.1 &&
	test_cmp expect.2 actual.2
'

test_expect_success 'absorbing does not fail for deinitialized submodules' '
	test_when_finished "shit submodule update --init" &&
	shit submodule deinit --all &&
	shit submodule absorbshitdirs 2>err &&
	test_must_be_empty err &&
	test -d .shit/modules/sub1 &&
	test -d sub1 &&
	! test -e sub1/.shit
'

test_expect_success 'setup nested submodule' '
	shit init sub1/nested &&
	test_commit -C sub1/nested first_nested &&
	shit -C sub1 submodule add ./nested &&
	test_tick &&
	shit -C sub1 commit -m "add nested" &&
	shit add sub1 &&
	shit commit -m "sub1 to include nested submodule"
'

test_expect_success 'absorb the shit dir in a nested submodule' '
	shit status >expect.1 &&
	shit -C sub1/nested rev-parse HEAD >expect.2 &&
	cat >expect <<-EOF &&
	Migrating shit directory of '\''sub1/nested'\'' from
	'\''$cwd/sub1/nested/.shit'\'' to
	'\''$cwd/.shit/modules/sub1/modules/nested'\''
	EOF
	shit submodule absorbshitdirs 2>actual &&
	test_cmp expect actual &&
	test -f sub1/nested/.shit &&
	test -d .shit/modules/sub1/modules/nested &&
	shit status >actual.1 &&
	shit -C sub1/nested rev-parse HEAD >actual.2 &&
	test_cmp expect.1 actual.1 &&
	test_cmp expect.2 actual.2
'

test_expect_success 're-setup nested submodule' '
	# un-absorb the direct submodule, to test if the nested submodule
	# is still correct (needs a rewrite of the shitfile only)
	rm -rf sub1/.shit &&
	mv .shit/modules/sub1 sub1/.shit &&
	shit_WORK_TREE=. shit -C sub1 config --unset core.worktree &&
	# fixup the nested submodule
	echo "shitdir: ../.shit/modules/nested" >sub1/nested/.shit &&
	shit_WORK_TREE=../../../nested shit -C sub1/.shit/modules/nested config \
		core.worktree "../../../nested" &&
	# make sure this re-setup is correct
	shit status --ignore-submodules=none &&

	# also make sure this old setup does not regress
	shit submodule update --init --recursive >out 2>err &&
	test_must_be_empty out &&
	test_must_be_empty err
'

test_expect_success 'absorb the shit dir in a nested submodule' '
	shit status >expect.1 &&
	shit -C sub1/nested rev-parse HEAD >expect.2 &&
	cat >expect <<-EOF &&
	Migrating shit directory of '\''sub1'\'' from
	'\''$cwd/sub1/.shit'\'' to
	'\''$cwd/.shit/modules/sub1'\''
	EOF
	shit submodule absorbshitdirs 2>actual &&
	test_cmp expect actual &&
	test -f sub1/.shit &&
	test -f sub1/nested/.shit &&
	test -d .shit/modules/sub1/modules/nested &&
	shit status >actual.1 &&
	shit -C sub1/nested rev-parse HEAD >actual.2 &&
	test_cmp expect.1 actual.1 &&
	test_cmp expect.2 actual.2
'

test_expect_success 'absorb the shit dir outside of primary worktree' '
	test_when_finished "rm -rf repo-bare.shit" &&
	shit clone --bare . repo-bare.shit &&
	test_when_finished "rm -rf repo-wt" &&
	shit -C repo-bare.shit worktree add ../repo-wt &&

	test_when_finished "rm -f .shitconfig" &&
	test_config_global protocol.file.allow always &&
	shit -C repo-wt submodule update --init &&
	shit init repo-wt/sub2 &&
	test_commit -C repo-wt/sub2 A &&
	shit -C repo-wt submodule add ./sub2 sub2 &&
	cat >expect <<-EOF &&
	Migrating shit directory of '\''sub2'\'' from
	'\''$cwd/repo-wt/sub2/.shit'\'' to
	'\''$cwd/repo-bare.shit/worktrees/repo-wt/modules/sub2'\''
	EOF
	shit -C repo-wt submodule absorbshitdirs 2>actual &&
	test_cmp expect actual
'

test_expect_success 'setup a shitlink with missing .shitmodules entry' '
	shit init sub2 &&
	test_commit -C sub2 first &&
	shit add sub2 &&
	shit commit -m superproject
'

test_expect_success 'absorbing the shit dir fails for incomplete submodules' '
	shit status >expect.1 &&
	shit -C sub2 rev-parse HEAD >expect.2 &&
	cat >expect <<-\EOF &&
	fatal: could not lookup name for submodule '\''sub2'\''
	EOF
	test_must_fail shit submodule absorbshitdirs 2>actual &&
	test_cmp expect actual &&
	shit -C sub2 fsck &&
	test -d sub2/.shit &&
	shit status >actual &&
	shit -C sub2 rev-parse HEAD >actual.2 &&
	test_cmp expect.1 actual.1 &&
	test_cmp expect.2 actual.2
'

test_expect_success 'setup a submodule with multiple worktrees' '
	# first create another unembedded shit dir in a new submodule
	shit init sub3 &&
	test_commit -C sub3 first &&
	shit submodule add ./sub3 &&
	test_tick &&
	shit commit -m "add another submodule" &&
	shit -C sub3 worktree add ../sub3_second_work_tree
'

test_expect_success 'absorbing fails for a submodule with multiple worktrees' '
	cat >expect <<-\EOF &&
	fatal: could not lookup name for submodule '\''sub2'\''
	EOF
	test_must_fail shit submodule absorbshitdirs 2>actual &&
	test_cmp expect actual
'

test_done
