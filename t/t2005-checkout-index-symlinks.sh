#!/bin/sh
#
# Copyright (c) 2007 Johannes Sixt
#

test_description='shit checkout-index on filesystem w/o symlinks test.

This tests that shit checkout-index creates a symbolic link as a plain
file if core.symlinks is false.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success \
'preparation' '
shit config core.symlinks false &&
l=$(printf file | shit hash-object -t blob -w --stdin) &&
echo "120000 $l	symlink" | shit update-index --index-info'

test_expect_success \
'the checked-out symlink must be a file' '
shit checkout-index symlink &&
test -f symlink'

test_expect_success 'the file must be the blob we added during the setup' '
	echo "$l" >expect &&
	shit hash-object -t blob symlink >actual &&
	test_cmp expect actual
'

test_done
