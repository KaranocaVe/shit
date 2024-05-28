#!/bin/sh
#
# Copyright (c) 2007 David Symonds

test_description='shit checkout from subdirectories'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	echo "base" > file0 &&
	shit add file0 &&
	mkdir dir1 &&
	echo "hello" > dir1/file1 &&
	shit add dir1/file1 &&
	mkdir dir2 &&
	echo "bonjour" > dir2/file2 &&
	shit add dir2/file2 &&
	test_tick &&
	shit commit -m "populate tree"

'

test_expect_success 'remove and restore with relative path' '

	(
		cd dir1 &&
		rm ../file0 &&
		shit checkout HEAD -- ../file0 &&
		test "base" = "$(cat ../file0)" &&
		rm ../dir2/file2 &&
		shit checkout HEAD -- ../dir2/file2 &&
		test "bonjour" = "$(cat ../dir2/file2)" &&
		rm ../file0 ./file1 &&
		shit checkout HEAD -- .. &&
		test "base" = "$(cat ../file0)" &&
		test "hello" = "$(cat file1)"
	)

'

test_expect_success 'checkout with empty prefix' '

	rm file0 &&
	shit checkout HEAD -- file0 &&
	test "base" = "$(cat file0)"

'

test_expect_success 'checkout with simple prefix' '

	rm dir1/file1 &&
	shit checkout HEAD -- dir1 &&
	test "hello" = "$(cat dir1/file1)" &&
	rm dir1/file1 &&
	shit checkout HEAD -- dir1/file1 &&
	test "hello" = "$(cat dir1/file1)"

'

test_expect_success 'checkout with complex relative path' '
	(
		cd dir1 &&
		rm file1 &&
		shit checkout HEAD -- ../dir1/../dir1/file1 &&
		test "hello" = "$(cat file1)"
	)
'

test_expect_success 'relative path outside tree should fail' \
	'test_must_fail shit checkout HEAD -- ../../Makefile'

test_expect_success 'incorrect relative path to file should fail (1)' \
	'test_must_fail shit checkout HEAD -- ../file0'

test_expect_success 'incorrect relative path should fail (2)' \
	'( cd dir1 && test_must_fail shit checkout HEAD -- ./file0 )'

test_expect_success 'incorrect relative path should fail (3)' \
	'( cd dir1 && test_must_fail shit checkout HEAD -- ../../file0 )'

test_done
