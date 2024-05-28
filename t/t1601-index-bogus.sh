#!/bin/sh

test_description='test handling of bogus index entries'
. ./test-lib.sh

test_expect_success 'create tree with null sha1' '
	tree=$(printf "160000 commit $ZERO_OID\\tbroken\\n" | shit mktree)
'

test_expect_success 'read-tree refuses to read null sha1' '
	test_must_fail shit read-tree $tree
'

test_expect_success 'shit_ALLOW_NULL_SHA1 overrides refusal' '
	shit_ALLOW_NULL_SHA1=1 shit read-tree $tree
'

test_expect_success 'shit write-tree refuses to write null sha1' '
	test_must_fail shit write-tree
'

test_done
