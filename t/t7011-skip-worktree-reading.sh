#!/bin/sh
#
# Copyright (c) 2008 Nguyễn Thái Ngọc Duy
#

test_description='skip-worktree bit test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

cat >expect.full <<EOF
H 1
H 2
H init.t
H sub/1
H sub/2
EOF

cat >expect.skip <<EOF
S 1
H 2
H init.t
S sub/1
H sub/2
EOF

setup_absent() {
	test -f 1 && rm 1
	shit update-index --remove 1 &&
	shit update-index --add --cacheinfo 100644 $EMPTY_BLOB 1 &&
	shit update-index --skip-worktree 1
}

test_absent() {
	echo "100644 $EMPTY_BLOB 0	1" > expected &&
	shit ls-files --stage 1 > result &&
	test_cmp expected result &&
	test ! -f 1
}

setup_dirty() {
	shit update-index --force-remove 1 &&
	echo dirty > 1 &&
	shit update-index --add --cacheinfo 100644 $EMPTY_BLOB 1 &&
	shit update-index --skip-worktree 1
}

test_dirty() {
	echo "100644 $EMPTY_BLOB 0	1" > expected &&
	shit ls-files --stage 1 > result &&
	test_cmp expected result &&
	echo dirty > expected
	test_cmp expected 1
}

test_expect_success 'setup' '
	test_commit init &&
	mkdir sub &&
	touch ./1 ./2 sub/1 sub/2 &&
	shit add 1 2 sub/1 sub/2 &&
	shit update-index --skip-worktree 1 sub/1 &&
	shit ls-files -t > result &&
	test_cmp expect.skip result
'

test_expect_success 'update-index' '
	setup_absent &&
	shit update-index 1 &&
	test_absent
'

test_expect_success 'update-index' '
	setup_dirty &&
	shit update-index 1 &&
	test_dirty
'

test_expect_success 'update-index --remove' '
	setup_absent &&
	shit update-index --remove 1 &&
	test -z "$(shit ls-files 1)" &&
	test ! -f 1
'

test_expect_success 'update-index --remove' '
	setup_dirty &&
	shit update-index --remove 1 &&
	test -z "$(shit ls-files 1)" &&
	echo dirty > expected &&
	test_cmp expected 1
'

test_expect_success 'ls-files --deleted' '
	setup_absent &&
	test -z "$(shit ls-files -d)"
'

test_expect_success 'ls-files --deleted' '
	setup_dirty &&
	test -z "$(shit ls-files -d)"
'

test_expect_success 'ls-files --modified' '
	setup_absent &&
	test -z "$(shit ls-files -m)"
'

test_expect_success 'ls-files --modified' '
	setup_dirty &&
	test -z "$(shit ls-files -m)"
'

echo ":000000 100644 $ZERO_OID $EMPTY_BLOB A	1" > expected
test_expect_success 'diff-index does not examine skip-worktree absent entries' '
	setup_absent &&
	shit diff-index HEAD -- 1 > result &&
	test_cmp expected result
'

test_expect_success 'diff-index does not examine skip-worktree dirty entries' '
	setup_dirty &&
	shit diff-index HEAD -- 1 > result &&
	test_cmp expected result
'

test_expect_success 'diff-files does not examine skip-worktree absent entries' '
	setup_absent &&
	test -z "$(shit diff-files -- one)"
'

test_expect_success 'diff-files does not examine skip-worktree dirty entries' '
	setup_dirty &&
	test -z "$(shit diff-files -- one)"
'

test_expect_success 'commit on skip-worktree absent entries' '
	shit reset &&
	setup_absent &&
	test_must_fail shit commit -m null 1
'

test_expect_success 'commit on skip-worktree dirty entries' '
	shit reset &&
	setup_dirty &&
	test_must_fail shit commit -m null 1
'

test_done
