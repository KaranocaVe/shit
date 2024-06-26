#!/bin/sh

test_description='shit commit races'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'race to create orphan commit' '
	write_script hare-editor <<-\EOF &&
	shit commit --allow-empty -m hare
	EOF
	test_must_fail env EDITOR=./hare-editor shit commit --allow-empty -m tortoise -e &&
	shit show -s --pretty=format:%s >subject &&
	grep hare subject &&
	shit show -s --pretty=format:%P >out &&
	test_must_be_empty out
'

test_expect_success 'race to create non-orphan commit' '
	write_script airplane-editor <<-\EOF &&
	shit commit --allow-empty -m airplane
	EOF
	shit checkout --orphan branch &&
	shit commit --allow-empty -m base &&
	shit rev-parse HEAD >base &&
	test_must_fail env EDITOR=./airplane-editor shit commit --allow-empty -m ship -e &&
	shit show -s --pretty=format:%s >subject &&
	grep airplane subject &&
	shit rev-parse HEAD^ >parent &&
	test_cmp base parent
'

test_done
