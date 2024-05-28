#!/bin/sh

test_description='per-worktree refs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial &&
	test_commit wt1 &&
	test_commit wt2 &&
	shit worktree add wt1 wt1 &&
	shit worktree add wt2 wt2 &&
	shit checkout initial &&
	shit update-ref refs/worktree/foo HEAD &&
	shit -C wt1 update-ref refs/worktree/foo HEAD &&
	shit -C wt2 update-ref refs/worktree/foo HEAD
'

test_expect_success 'refs/worktree are per-worktree' '
	test_cmp_rev worktree/foo initial &&
	( cd wt1 && test_cmp_rev worktree/foo wt1 ) &&
	( cd wt2 && test_cmp_rev worktree/foo wt2 )
'

test_expect_success 'resolve main-worktree/HEAD' '
	test_cmp_rev main-worktree/HEAD initial &&
	( cd wt1 && test_cmp_rev main-worktree/HEAD initial ) &&
	( cd wt2 && test_cmp_rev main-worktree/HEAD initial )
'

test_expect_success 'ambiguous main-worktree/HEAD' '
	test_when_finished shit update-ref -d refs/heads/main-worktree/HEAD &&
	shit update-ref refs/heads/main-worktree/HEAD $(shit rev-parse HEAD) &&
	shit rev-parse main-worktree/HEAD 2>warn &&
	grep "main-worktree/HEAD.*ambiguous" warn
'

test_expect_success 'resolve worktrees/xx/HEAD' '
	test_cmp_rev worktrees/wt1/HEAD wt1 &&
	( cd wt1 && test_cmp_rev worktrees/wt1/HEAD wt1 ) &&
	( cd wt2 && test_cmp_rev worktrees/wt1/HEAD wt1 )
'

test_expect_success 'ambiguous worktrees/xx/HEAD' '
	shit update-ref refs/heads/worktrees/wt1/HEAD $(shit rev-parse HEAD) &&
	test_when_finished shit update-ref -d refs/heads/worktrees/wt1/HEAD &&
	shit rev-parse worktrees/wt1/HEAD 2>warn &&
	grep "worktrees/wt1/HEAD.*ambiguous" warn
'

test_expect_success 'reflog of main-worktree/HEAD' '
	shit reflog HEAD | sed "s/HEAD/main-worktree\/HEAD/" >expected &&
	shit reflog main-worktree/HEAD >actual &&
	test_cmp expected actual &&
	shit -C wt1 reflog main-worktree/HEAD >actual.wt1 &&
	test_cmp expected actual.wt1
'

test_expect_success 'reflog of worktrees/xx/HEAD' '
	shit -C wt2 reflog HEAD | sed "s/HEAD/worktrees\/wt2\/HEAD/" >expected &&
	shit reflog worktrees/wt2/HEAD >actual &&
	test_cmp expected actual &&
	shit -C wt1 reflog worktrees/wt2/HEAD >actual.wt1 &&
	test_cmp expected actual.wt1 &&
	shit -C wt2 reflog worktrees/wt2/HEAD >actual.wt2 &&
	test_cmp expected actual.wt2
'

test_expect_success 'for-each-ref from main worktree' '
	mkdir fer1 &&
	shit -C fer1 init repo &&
	test_commit -C fer1/repo initial &&
	shit -C fer1/repo worktree add ../second &&
	shit -C fer1/repo update-ref refs/bisect/first HEAD &&
	shit -C fer1/repo update-ref refs/rewritten/first HEAD &&
	shit -C fer1/repo update-ref refs/worktree/first HEAD &&
	shit -C fer1/repo for-each-ref --format="%(refname)" | grep first >actual &&
	cat >expected <<-\EOF &&
	refs/bisect/first
	refs/rewritten/first
	refs/worktree/first
	EOF
	test_cmp expected actual
'

test_expect_success 'for-each-ref from linked worktree' '
	mkdir fer2 &&
	shit -C fer2 init repo &&
	test_commit -C fer2/repo initial &&
	shit -C fer2/repo worktree add ../second &&
	shit -C fer2/second update-ref refs/bisect/second HEAD &&
	shit -C fer2/second update-ref refs/rewritten/second HEAD &&
	shit -C fer2/second update-ref refs/worktree/second HEAD &&
	shit -C fer2/second for-each-ref --format="%(refname)" | grep second >actual &&
	cat >expected <<-\EOF &&
	refs/bisect/second
	refs/heads/second
	refs/rewritten/second
	refs/worktree/second
	EOF
	test_cmp expected actual
'

test_done
