#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='shit read-tree --prefix test.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo hello >one &&
	shit update-index --add one &&
	tree=$(shit write-tree) &&
	echo tree is $tree
'

echo 'one
two/one' >expect

test_expect_success 'read-tree --prefix' '
	shit read-tree --prefix=two/ $tree &&
	shit ls-files >actual &&
	cmp expect actual
'

test_expect_success 'read-tree --prefix with leading slash exits with error' '
	shit rm -rf . &&
	test_must_fail shit read-tree --prefix=/two/ $tree &&
	shit read-tree --prefix=two/ $tree &&

	shit rm -rf . &&
	test_must_fail shit read-tree --prefix=/ $tree &&
	shit read-tree --prefix= $tree
'

test_done
