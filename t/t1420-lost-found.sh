#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='Test fsck --lost-found'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit config core.logAllRefUpdates 0 &&
	: > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m initial &&
	echo 1 > file1 &&
	echo 2 > file2 &&
	shit add file1 file2 &&
	test_tick &&
	shit commit -m second &&
	echo 3 > file3 &&
	shit add file3
'

test_expect_success 'lost and found something' '
	shit rev-parse HEAD > lost-commit &&
	shit rev-parse :file3 > lost-other &&
	test_tick &&
	shit reset --hard HEAD^ &&
	shit fsck --lost-found &&
	test 2 = $(ls .shit/lost-found/*/* | wc -l) &&
	test -f .shit/lost-found/commit/$(cat lost-commit) &&
	test -f .shit/lost-found/other/$(cat lost-other)
'

test_done
