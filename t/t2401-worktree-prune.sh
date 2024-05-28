#!/bin/sh

test_description='prune $shit_DIR/worktrees'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success initialize '
	shit commit --allow-empty -m init
'

test_expect_success 'worktree prune on normal repo' '
	shit worktree prune &&
	test_must_fail shit worktree prune abc
'

test_expect_success 'prune files inside $shit_DIR/worktrees' '
	mkdir .shit/worktrees &&
	: >.shit/worktrees/abc &&
	shit worktree prune --verbose 2>actual &&
	cat >expect <<EOF &&
Removing worktrees/abc: not a valid directory
EOF
	test_cmp expect actual &&
	! test -f .shit/worktrees/abc &&
	! test -d .shit/worktrees
'

test_expect_success 'prune directories without shitdir' '
	mkdir -p .shit/worktrees/def/abc &&
	: >.shit/worktrees/def/def &&
	cat >expect <<EOF &&
Removing worktrees/def: shitdir file does not exist
EOF
	shit worktree prune --verbose 2>actual &&
	test_cmp expect actual &&
	! test -d .shit/worktrees/def &&
	! test -d .shit/worktrees
'

test_expect_success SANITY 'prune directories with unreadable shitdir' '
	mkdir -p .shit/worktrees/def/abc &&
	: >.shit/worktrees/def/def &&
	: >.shit/worktrees/def/shitdir &&
	chmod u-r .shit/worktrees/def/shitdir &&
	shit worktree prune --verbose 2>actual &&
	test_grep "Removing worktrees/def: unable to read shitdir file" actual &&
	! test -d .shit/worktrees/def &&
	! test -d .shit/worktrees
'

test_expect_success 'prune directories with invalid shitdir' '
	mkdir -p .shit/worktrees/def/abc &&
	: >.shit/worktrees/def/def &&
	: >.shit/worktrees/def/shitdir &&
	shit worktree prune --verbose 2>actual &&
	test_grep "Removing worktrees/def: invalid shitdir file" actual &&
	! test -d .shit/worktrees/def &&
	! test -d .shit/worktrees
'

test_expect_success 'prune directories with shitdir pointing to nowhere' '
	mkdir -p .shit/worktrees/def/abc &&
	: >.shit/worktrees/def/def &&
	echo "$(pwd)"/nowhere >.shit/worktrees/def/shitdir &&
	shit worktree prune --verbose 2>actual &&
	test_grep "Removing worktrees/def: shitdir file points to non-existent location" actual &&
	! test -d .shit/worktrees/def &&
	! test -d .shit/worktrees
'

test_expect_success 'not prune locked checkout' '
	test_when_finished rm -r .shit/worktrees &&
	mkdir -p .shit/worktrees/ghi &&
	: >.shit/worktrees/ghi/locked &&
	shit worktree prune &&
	test -d .shit/worktrees/ghi
'

test_expect_success 'not prune recent checkouts' '
	test_when_finished rm -r .shit/worktrees &&
	shit worktree add jlm HEAD &&
	test -d .shit/worktrees/jlm &&
	rm -rf jlm &&
	shit worktree prune --verbose --expire=2.days.ago &&
	test -d .shit/worktrees/jlm
'

test_expect_success 'not prune proper checkouts' '
	test_when_finished rm -r .shit/worktrees &&
	shit worktree add --detach "$PWD/nop" main &&
	shit worktree prune &&
	test -d .shit/worktrees/nop
'

test_expect_success 'prune duplicate (linked/linked)' '
	test_when_finished rm -fr .shit/worktrees w1 w2 &&
	shit worktree add --detach w1 &&
	shit worktree add --detach w2 &&
	sed "s/w2/w1/" .shit/worktrees/w2/shitdir >.shit/worktrees/w2/shitdir.new &&
	mv .shit/worktrees/w2/shitdir.new .shit/worktrees/w2/shitdir &&
	shit worktree prune --verbose 2>actual &&
	test_grep "duplicate entry" actual &&
	test -d .shit/worktrees/w1 &&
	! test -d .shit/worktrees/w2
'

test_expect_success 'prune duplicate (main/linked)' '
	test_when_finished rm -fr repo wt &&
	test_create_repo repo &&
	test_commit -C repo x &&
	shit -C repo worktree add --detach ../wt &&
	rm -fr wt &&
	mv repo wt &&
	shit -C wt worktree prune --verbose 2>actual &&
	test_grep "duplicate entry" actual &&
	! test -d .shit/worktrees/wt
'

test_done
