#!/bin/sh
#
# Copyright (c) 2010 Brad King
#

test_description='shit update-index for shitlink to .shit file.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'submodule with absolute .shit file' '
	mkdir sub1 &&
	(cd sub1 &&
	 shit init &&
	 REAL="$(pwd)/.real" &&
	 mv .shit "$REAL" &&
	 echo "shitdir: $REAL" >.shit &&
	 test_commit first)
'

test_expect_success 'add shitlink to absolute .shit file' '
	shit update-index --add -- sub1
'

test_expect_success 'submodule with relative .shit file' '
	mkdir sub2 &&
	(cd sub2 &&
	 shit init &&
	 mv .shit .real &&
	 echo "shitdir: .real" >.shit &&
	 test_commit first)
'

test_expect_success 'add shitlink to relative .shit file' '
	shit update-index --add -- sub2
'

test_done
