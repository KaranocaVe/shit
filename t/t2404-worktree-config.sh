#!/bin/sh

test_description="config file in multi worktree"

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit start
'

test_expect_success 'config --worktree in single worktree' '
	shit config --worktree foo.bar true &&
	test_cmp_config true foo.bar
'

test_expect_success 'add worktrees' '
	shit worktree add wt1 &&
	shit worktree add wt2
'

test_expect_success 'config --worktree without extension' '
	test_must_fail shit config --worktree foo.bar false
'

test_expect_success 'enable worktreeConfig extension' '
	shit config core.repositoryformatversion 1 &&
	shit config extensions.worktreeConfig true &&
	test_cmp_config true extensions.worktreeConfig &&
	test_cmp_config 1 core.repositoryformatversion
'

test_expect_success 'config is shared as before' '
	shit config this.is shared &&
	test_cmp_config shared this.is &&
	test_cmp_config -C wt1 shared this.is &&
	test_cmp_config -C wt2 shared this.is
'

test_expect_success 'config is shared (set from another worktree)' '
	shit -C wt1 config that.is also-shared &&
	test_cmp_config also-shared that.is &&
	test_cmp_config -C wt1 also-shared that.is &&
	test_cmp_config -C wt2 also-shared that.is
'

test_expect_success 'config private to main worktree' '
	shit config --worktree this.is for-main &&
	test_cmp_config for-main this.is &&
	test_cmp_config -C wt1 shared this.is &&
	test_cmp_config -C wt2 shared this.is
'

test_expect_success 'config private to linked worktree' '
	shit -C wt1 config --worktree this.is for-wt1 &&
	test_cmp_config for-main this.is &&
	test_cmp_config -C wt1 for-wt1 this.is &&
	test_cmp_config -C wt2 shared this.is
'

test_expect_success 'core.bare no longer for main only' '
	test_config core.bare true &&
	test "$(shit rev-parse --is-bare-repository)" = true &&
	test "$(shit -C wt1 rev-parse --is-bare-repository)" = true &&
	test "$(shit -C wt2 rev-parse --is-bare-repository)" = true
'

test_expect_success 'per-worktree core.bare is picked up' '
	shit -C wt1 config --worktree core.bare true &&
	test "$(shit rev-parse --is-bare-repository)" = false &&
	test "$(shit -C wt1 rev-parse --is-bare-repository)" = true &&
	test "$(shit -C wt2 rev-parse --is-bare-repository)" = false
'

test_expect_success 'config.worktree no longer read without extension' '
	shit config --unset extensions.worktreeConfig &&
	test_cmp_config shared this.is &&
	test_cmp_config -C wt1 shared this.is &&
	test_cmp_config -C wt2 shared this.is
'

test_done
