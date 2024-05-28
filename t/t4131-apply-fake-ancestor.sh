#!/bin/sh
#
# Copyright (c) 2009 Stephen Boyd
#

test_description='shit apply --build-fake-ancestor handling.'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit 1 &&
	test_commit 2 &&
	mkdir sub &&
	test_commit 3 sub/3.t &&
	test_commit 4
'

test_expect_success 'apply --build-fake-ancestor' '
	shit checkout 2 &&
	echo "A" > 1.t &&
	shit diff > 1.patch &&
	shit reset --hard &&
	shit checkout 1 &&
	shit apply --build-fake-ancestor 1.ancestor 1.patch
'

test_expect_success 'apply --build-fake-ancestor in a subdirectory' '
	shit checkout 3 &&
	echo "C" > sub/3.t &&
	shit diff > 3.patch &&
	shit reset --hard &&
	shit checkout 4 &&
	(
		cd sub &&
		shit apply --build-fake-ancestor 3.ancestor ../3.patch &&
		test -f 3.ancestor
	) &&
	shit apply --build-fake-ancestor 3.ancestor 3.patch &&
	test_cmp sub/3.ancestor 3.ancestor
'

test_done
