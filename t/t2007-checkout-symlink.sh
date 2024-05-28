#!/bin/sh
#
# Copyright (c) 2007 Junio C Hamano

test_description='shit checkout to switch between branches with symlink<->dir'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	mkdir frotz &&
	echo hello >frotz/filfre &&
	shit add frotz/filfre &&
	test_tick &&
	shit commit -m "main has file frotz/filfre" &&

	shit branch side &&

	echo goodbye >nitfol &&
	shit add nitfol &&
	test_tick &&
	shit commit -m "main adds file nitfol" &&

	shit checkout side &&

	shit rm --cached frotz/filfre &&
	mv frotz xyzzy &&
	test_ln_s_add xyzzy frotz &&
	shit add xyzzy/filfre &&
	test_tick &&
	shit commit -m "side moves frotz/ to xyzzy/ and adds frotz->xyzzy/"

'

test_expect_success 'switch from symlink to dir' '

	shit checkout main

'

test_expect_success 'Remove temporary directories & switch to main' '
	rm -fr frotz xyzzy nitfol &&
	shit checkout -f main
'

test_expect_success 'switch from dir to symlink' '

	shit checkout side

'

test_done
