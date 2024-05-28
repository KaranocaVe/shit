#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='shit rev-list involving submodules that this repo has'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	: > file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	echo 1 > file &&
	test_tick &&
	shit commit -m second file &&
	echo 2 > file &&
	test_tick &&
	shit commit -m third file &&

	rm .shit/index &&

	: > super-file &&
	shit add super-file &&
	shit -c protocol.file.allow=always submodule add "$(pwd)" sub &&
	shit symbolic-ref HEAD refs/heads/super &&
	test_tick &&
	shit commit -m super-initial &&
	echo 1 > super-file &&
	test_tick &&
	shit commit -m super-first super-file &&
	echo 2 > super-file &&
	test_tick &&
	shit commit -m super-second super-file
'

test_expect_success "Ilari's test" '
	shit rev-list --objects super main ^super^
'

test_done
