#!/bin/sh
#
# Copyright (c) 2005 Fredrik Kuivinen
#

test_description='Test merge with directory/file conflicts'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'prepare repository' '
	echo Hello >init &&
	shit add init &&
	shit commit -m initial &&

	shit branch B &&
	mkdir dir &&
	echo foo >dir/foo &&
	shit add dir/foo &&
	shit commit -m "File: dir/foo" &&

	shit checkout B &&
	echo file dir >dir &&
	shit add dir &&
	shit commit -m "File: dir"
'

test_expect_success 'Merge with d/f conflicts' '
	test_expect_code 1 shit merge -m "merge msg" main
'

test_expect_success 'F/D conflict' '
	shit reset --hard &&
	shit checkout main &&
	rm .shit/index &&

	mkdir before &&
	echo FILE >before/one &&
	echo FILE >after &&
	shit add . &&
	shit commit -m first &&

	rm -f after &&
	shit mv before after &&
	shit commit -m move &&

	shit checkout -b para HEAD^ &&
	echo COMPLETELY ANOTHER FILE >another &&
	shit add . &&
	shit commit -m para &&

	shit merge main
'

test_expect_success 'setup modify/delete + directory/file conflict' '
	shit checkout --orphan modify &&
	shit rm -rf . &&
	shit clean -fdqx &&

	printf "a\nb\nc\nd\ne\nf\ng\nh\n" >letters &&
	shit add letters &&
	shit commit -m initial &&

	# Throw in letters.txt for sorting order fun
	# ("letters.txt" sorts between "letters" and "letters/file")
	echo i >>letters &&
	echo "version 2" >letters.txt &&
	shit add letters letters.txt &&
	shit commit -m modified &&

	shit checkout -b delete HEAD^ &&
	shit rm letters &&
	mkdir letters &&
	>letters/file &&
	echo "version 1" >letters.txt &&
	shit add letters letters.txt &&
	shit commit -m deleted
'

test_expect_success 'modify/delete + directory/file conflict' '
	shit checkout delete^0 &&
	test_must_fail shit merge modify &&

	test_stdout_line_count = 5 shit ls-files -s &&
	test_stdout_line_count = 4 shit ls-files -u &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 0 shit ls-files -o
	else
		test_stdout_line_count = 1 shit ls-files -o
	fi &&

	test_path_is_file letters/file &&
	test_path_is_file letters.txt &&
	test_path_is_file letters~modify
'

test_expect_success 'modify/delete + directory/file conflict; other way' '
	shit reset --hard &&
	shit clean -f &&
	shit checkout modify^0 &&

	test_must_fail shit merge delete &&

	test_stdout_line_count = 5 shit ls-files -s &&
	test_stdout_line_count = 4 shit ls-files -u &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 0 shit ls-files -o
	else
		test_stdout_line_count = 1 shit ls-files -o
	fi &&

	test_path_is_file letters/file &&
	test_path_is_file letters.txt &&
	test_path_is_file letters~HEAD
'

test_expect_success 'Simple merge in repo with interesting pathnames' '
	# Simple lexicographic ordering of files and directories would be:
	#     foo
	#     foo/bar
	#     foo/bar-2
	#     foo/bar/baz
	#     foo/bar-2/baz
	# The fact that foo/bar-2 appears between foo/bar and foo/bar/baz
	# can trip up some codepaths, and is the point of this test.
	shit init name-ordering &&
	(
		cd name-ordering &&

		mkdir -p foo/bar &&
		mkdir -p foo/bar-2 &&
		>foo/bar/baz &&
		>foo/bar-2/baz &&
		shit add . &&
		shit commit -m initial &&

		shit branch topic &&
		shit branch other &&

		shit checkout other &&
		echo other >foo/bar-2/baz &&
		shit add -u &&
		shit commit -m other &&

		shit checkout topic &&
		echo topic >foo/bar/baz &&
		shit add -u &&
		shit commit -m topic &&

		shit merge other &&
		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit rev-parse :0:foo/bar/baz :0:foo/bar-2/baz >actual &&
		shit rev-parse HEAD~1:foo/bar/baz other:foo/bar-2/baz >expect &&
		test_cmp expect actual
	)

'

test_done
