#!/bin/sh
#
# Copyright (c) 2006 Shawn Pearce
#

test_description='shit reset should cull empty subdirs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff-data.sh

test_expect_success 'creating initial files' '
	mkdir path0 &&
	COPYING_test_data >path0/COPYING &&
	shit add path0/COPYING &&
	shit commit -m add -a
'

test_expect_success 'creating second files' '
	mkdir path1 &&
	mkdir path1/path2 &&
	COPYING_test_data >path1/path2/COPYING &&
	COPYING_test_data >path1/COPYING &&
	COPYING_test_data >COPYING &&
	COPYING_test_data >path0/COPYING-TOO &&
	shit add path1/path2/COPYING &&
	shit add path1/COPYING &&
	shit add COPYING &&
	shit add path0/COPYING-TOO &&
	shit commit -m change -a
'

test_expect_success 'resetting tree HEAD^' '
	shit reset --hard HEAD^
'

test_expect_success 'checking initial files exist after rewind' '
	test -d path0 &&
	test -f path0/COPYING
'

test_expect_success 'checking lack of path1/path2/COPYING' '
	! test -f path1/path2/COPYING
'

test_expect_success 'checking lack of path1/COPYING' '
	! test -f path1/COPYING
'

test_expect_success 'checking lack of COPYING' '
	! test -f COPYING
'

test_expect_success 'checking checking lack of path1/COPYING-TOO' '
	! test -f path0/COPYING-TOO
'

test_expect_success 'checking lack of path1/path2' '
	! test -d path1/path2
'

test_expect_success 'checking lack of path1' '
	! test -d path1
'

test_done
