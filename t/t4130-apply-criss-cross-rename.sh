#!/bin/sh

test_description='shit apply handling criss-cross rename patch.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

create_file() {
	cnt=0
	while test $cnt -le 100
	do
		cnt=$(($cnt + 1))
		echo "$2" >> "$1"
	done
}

test_expect_success 'setup' '
	# Ensure that file sizes are different, because on Windows
	# lstat() does not discover inode numbers, and we need
	# other properties to discover swapped files
	# (mtime is not always different, either).
	create_file file1 "some content" &&
	create_file file2 "some other content" &&
	create_file file3 "again something else" &&
	shit add file1 file2 file3 &&
	shit commit -m 1
'

test_expect_success 'criss-cross rename' '
	mv file1 tmp &&
	mv file2 file1 &&
	mv tmp file2 &&
	cp file1 file1-swapped &&
	cp file2 file2-swapped
'

test_expect_success 'diff -M -B' '
	shit diff -M -B > diff &&
	shit reset --hard

'

test_expect_success 'apply' '
	shit apply diff &&
	test_cmp file1 file1-swapped &&
	test_cmp file2 file2-swapped
'

test_expect_success 'criss-cross rename' '
	shit reset --hard &&
	mv file1 tmp &&
	mv file2 file1 &&
	mv file3 file2 &&
	mv tmp file3 &&
	cp file1 file1-swapped &&
	cp file2 file2-swapped &&
	cp file3 file3-swapped
'

test_expect_success 'diff -M -B' '
	shit diff -M -B > diff &&
	shit reset --hard
'

test_expect_success 'apply' '
	shit apply diff &&
	test_cmp file1 file1-swapped &&
	test_cmp file2 file2-swapped &&
	test_cmp file3 file3-swapped
'

test_done
