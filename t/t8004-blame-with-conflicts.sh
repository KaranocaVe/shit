#!/bin/sh

# Based on a test case submitted by Björn Steinbrink.

test_description='shit blame on conflicted files'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup first case' '
	# Create the old file
	echo "Old line" > file1 &&
	shit add file1 &&
	shit commit --author "Old Line <ol@localhost>" -m file1.a &&

	# Branch
	shit checkout -b foo &&

	# Do an ugly move and change
	shit rm file1 &&
	echo "New line ..."  > file2 &&
	echo "... and more" >> file2 &&
	shit add file2 &&
	shit commit --author "U Gly <ug@localhost>" -m ugly &&

	# Back to main and change something
	shit checkout main &&
	echo "

bla" >> file1 &&
	shit commit --author "Old Line <ol@localhost>" -a -m file1.b &&

	# Back to foo and merge main
	shit checkout foo &&
	if shit merge main; then
		echo needed conflict here
		exit 1
	else
		echo merge failed - resolving automatically
	fi &&
	echo "New line ...
... and more

bla
Even more" > file2 &&
	shit rm file1 &&
	shit commit --author "M Result <mr@localhost>" -a -m merged &&

	# Back to main and change file1 again
	shit checkout main &&
	sed s/bla/foo/ <file1 >X &&
	rm file1 &&
	mv X file1 &&
	shit commit --author "No Bla <nb@localhost>" -a -m replace &&

	# Try to merge into foo again
	shit checkout foo &&
	if shit merge main; then
		echo needed conflict here
		exit 1
	else
		echo merge failed - test is setup
	fi
'

test_expect_success \
	'blame runs on unconflicted file while other file has conflicts' '
	shit blame file2
'

test_expect_success 'blame does not crash with conflicted file in stages 1,3' '
	shit blame file1
'

test_done
