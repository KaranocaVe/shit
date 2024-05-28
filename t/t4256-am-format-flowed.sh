#!/bin/sh

test_description='test format=flowed support of shit am'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cp "$TEST_DIRECTORY/t4256/1/mailinfo.c.orig" mailinfo.c &&
	shit add mailinfo.c &&
	shit commit -m initial
'

test_expect_success 'am with format=flowed' '
	shit am <"$TEST_DIRECTORY/t4256/1/patch" 2>stderr &&
	test_grep "warning: Patch sent with format=flowed" stderr &&
	test_cmp "$TEST_DIRECTORY/t4256/1/mailinfo.c" mailinfo.c
'

test_done
