#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
# Copyright (c) 2005 Robert Fitzsimons
#

test_description='shit apply test patches with multiple fragments.'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

cp "$TEST_DIRECTORY/t4109/patch1.patch" .
cp "$TEST_DIRECTORY/t4109/patch2.patch" .
cp "$TEST_DIRECTORY/t4109/patch3.patch" .
cp "$TEST_DIRECTORY/t4109/patch4.patch" .

test_expect_success 'shit apply (1)' '
	shit apply patch1.patch patch2.patch &&
	test_cmp "$TEST_DIRECTORY/t4109/expect-1" main.c
'
rm -f main.c

test_expect_success 'shit apply (2)' '
	shit apply patch1.patch patch2.patch patch3.patch &&
	test_cmp "$TEST_DIRECTORY/t4109/expect-2" main.c
'
rm -f main.c

test_expect_success 'shit apply (3)' '
	shit apply patch1.patch patch4.patch &&
	test_cmp "$TEST_DIRECTORY/t4109/expect-3" main.c
'
mv main.c main.c.shit

test_done

