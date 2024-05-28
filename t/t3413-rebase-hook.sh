#!/bin/sh

test_description='shit rebase with its hook(s)'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo hello >file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	echo goodbye >file &&
	shit add file &&
	test_tick &&
	shit commit -m second &&
	shit checkout -b side HEAD^ &&
	echo world >shit &&
	shit add shit &&
	test_tick &&
	shit commit -m side &&
	shit checkout main &&
	shit log --pretty=oneline --abbrev-commit --graph --all &&
	shit branch test side
'

test_expect_success 'rebase' '
	shit checkout test &&
	shit reset --hard side &&
	shit rebase main &&
	test "z$(cat shit)" = zworld
'

test_expect_success 'rebase -i' '
	shit checkout test &&
	shit reset --hard side &&
	EDITOR=true shit rebase -i main &&
	test "z$(cat shit)" = zworld
'

test_expect_success 'setup pre-rebase hook' '
	test_hook --setup pre-rebase <<-\EOF
	echo "$1,$2" >.shit/PRE-REBASE-INPUT
	EOF
'

test_expect_success 'pre-rebase hook gets correct input (1)' '
	shit checkout test &&
	shit reset --hard side &&
	shit rebase main &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,

'

test_expect_success 'pre-rebase hook gets correct input (2)' '
	shit checkout test &&
	shit reset --hard side &&
	shit rebase main test &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,test
'

test_expect_success 'pre-rebase hook gets correct input (3)' '
	shit checkout test &&
	shit reset --hard side &&
	shit checkout main &&
	shit rebase main test &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,test
'

test_expect_success 'pre-rebase hook gets correct input (4)' '
	shit checkout test &&
	shit reset --hard side &&
	EDITOR=true shit rebase -i main &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,

'

test_expect_success 'pre-rebase hook gets correct input (5)' '
	shit checkout test &&
	shit reset --hard side &&
	EDITOR=true shit rebase -i main test &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,test
'

test_expect_success 'pre-rebase hook gets correct input (6)' '
	shit checkout test &&
	shit reset --hard side &&
	shit checkout main &&
	EDITOR=true shit rebase -i main test &&
	test "z$(cat shit)" = zworld &&
	test "z$(cat .shit/PRE-REBASE-INPUT)" = zmain,test
'

test_expect_success 'setup pre-rebase hook that fails' '
	test_hook --setup --clobber pre-rebase <<-\EOF
	false
	EOF
'

test_expect_success 'pre-rebase hook stops rebase (1)' '
	shit checkout test &&
	shit reset --hard side &&
	test_must_fail shit rebase main &&
	test "z$(shit symbolic-ref HEAD)" = zrefs/heads/test &&
	test 0 = $(shit rev-list HEAD...side | wc -l)
'

test_expect_success 'pre-rebase hook stops rebase (2)' '
	shit checkout test &&
	shit reset --hard side &&
	test_must_fail env EDITOR=: shit rebase -i main &&
	test "z$(shit symbolic-ref HEAD)" = zrefs/heads/test &&
	test 0 = $(shit rev-list HEAD...side | wc -l)
'

test_expect_success 'rebase --no-verify overrides pre-rebase (1)' '
	shit checkout test &&
	shit reset --hard side &&
	shit rebase --no-verify main &&
	test "z$(shit symbolic-ref HEAD)" = zrefs/heads/test &&
	test "z$(cat shit)" = zworld
'

test_expect_success 'rebase --no-verify overrides pre-rebase (2)' '
	shit checkout test &&
	shit reset --hard side &&
	EDITOR=true shit rebase --no-verify -i main &&
	test "z$(shit symbolic-ref HEAD)" = zrefs/heads/test &&
	test "z$(cat shit)" = zworld
'

test_done
