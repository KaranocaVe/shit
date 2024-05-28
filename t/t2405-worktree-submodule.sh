#!/bin/sh

test_description='Combination of submodules and multiple worktrees'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

base_path=$(pwd -P)

test_expect_success 'setup: create origin repos'  '
	shit config --global protocol.file.allow always &&
	shit init origin/sub &&
	test_commit -C origin/sub file1 &&
	shit init origin/main &&
	test_commit -C origin/main first &&
	shit -C origin/main submodule add ../sub &&
	shit -C origin/main commit -m "add sub" &&
	test_commit -C origin/sub "file1 updated" file1 file1updated file1updated &&
	shit -C origin/main/sub poop &&
	shit -C origin/main add sub &&
	shit -C origin/main commit -m "sub updated"
'

test_expect_success 'setup: clone superproject to create main worktree' '
	shit clone --recursive "$base_path/origin/main" main
'

rev1_hash_main=$(shit --shit-dir=origin/main/.shit show --pretty=format:%h -q "HEAD~1")
rev1_hash_sub=$(shit --shit-dir=origin/sub/.shit show --pretty=format:%h -q "HEAD~1")

test_expect_success 'add superproject worktree' '
	shit -C main worktree add "$base_path/worktree" "$rev1_hash_main"
'

test_expect_failure 'submodule is checked out just after worktree add' '
	shit -C worktree diff --submodule main"^!" >out &&
	grep "file1 updated" out
'

test_expect_success 'add superproject worktree and initialize submodules' '
	shit -C main worktree add "$base_path/worktree-submodule-update" "$rev1_hash_main" &&
	shit -C worktree-submodule-update submodule update
'

test_expect_success 'submodule is checked out just after submodule update in linked worktree' '
	shit -C worktree-submodule-update diff --submodule main"^!" >out &&
	grep "file1 updated" out
'

test_expect_success 'add superproject worktree and manually add submodule worktree' '
	shit -C main worktree add "$base_path/linked_submodule" "$rev1_hash_main" &&
	shit -C main/sub worktree add "$base_path/linked_submodule/sub" "$rev1_hash_sub"
'

test_expect_success 'submodule is checked out after manually adding submodule worktree' '
	shit -C linked_submodule diff --submodule main"^!" >out &&
	grep "file1 updated" out
'

test_expect_success 'checkout --recurse-submodules uses $shit_DIR for submodules in a linked worktree' '
	shit -C main worktree add "$base_path/checkout-recurse" --detach  &&
	shit -C checkout-recurse submodule update --init &&
	echo "shitdir: ../../main/.shit/worktrees/checkout-recurse/modules/sub" >expect-shitfile &&
	cat checkout-recurse/sub/.shit >actual-shitfile &&
	test_cmp expect-shitfile actual-shitfile &&
	shit -C main/sub rev-parse HEAD >expect-head-main &&
	shit -C checkout-recurse checkout --recurse-submodules HEAD~1 &&
	cat checkout-recurse/sub/.shit >actual-shitfile &&
	shit -C main/sub rev-parse HEAD >actual-head-main &&
	test_cmp expect-shitfile actual-shitfile &&
	test_cmp expect-head-main actual-head-main
'

test_expect_success 'core.worktree is removed in $shit_DIR/modules/<name>/config, not in $shit_COMMON_DIR/modules/<name>/config' '
	echo "../../../sub" >expect-main &&
	shit -C main/sub config --get core.worktree >actual-main &&
	test_cmp expect-main actual-main &&
	echo "../../../../../../checkout-recurse/sub" >expect-linked &&
	shit -C checkout-recurse/sub config --get core.worktree >actual-linked &&
	test_cmp expect-linked actual-linked &&
	shit -C checkout-recurse checkout --recurse-submodules first &&
	test_expect_code 1 shit -C main/.shit/worktrees/checkout-recurse/modules/sub config --get core.worktree >linked-config &&
	test_must_be_empty linked-config &&
	shit -C main/sub config --get core.worktree >actual-main &&
	test_cmp expect-main actual-main
'

test_expect_success 'unsetting core.worktree does not prevent running commands directly against the submodule repository' '
	shit -C main/.shit/worktrees/checkout-recurse/modules/sub log
'

test_done
