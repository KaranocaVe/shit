#!/bin/sh

test_description='test main ref store api'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

RUN="test-tool ref-store main"


test_expect_success 'setup' '
	test_commit one
'

test_expect_success 'create_symref(FOO, refs/heads/main)' '
	$RUN create-symref FOO refs/heads/main nothing &&
	echo refs/heads/main >expected &&
	shit symbolic-ref FOO >actual &&
	test_cmp expected actual
'

test_expect_success 'delete_refs(FOO, refs/tags/new-tag)' '
	shit tag -a -m new-tag new-tag HEAD &&
	shit rev-parse FOO -- &&
	shit rev-parse refs/tags/new-tag -- &&
	m=$(shit rev-parse main) &&
	$RUN delete-refs REF_NO_DEREF nothing FOO refs/tags/new-tag &&
	test_must_fail shit rev-parse --symbolic-full-name FOO &&
	test_must_fail shit rev-parse FOO -- &&
	test_must_fail shit rev-parse refs/tags/new-tag --
'

test_expect_success 'rename_refs(main, new-main)' '
	shit rev-parse main >expected &&
	$RUN rename-ref refs/heads/main refs/heads/new-main &&
	shit rev-parse new-main >actual &&
	test_cmp expected actual &&
	test_commit recreate-main
'

test_expect_success 'for_each_ref(refs/heads/)' '
	$RUN for-each-ref refs/heads/ | cut -d" " -f 2- >actual &&
	cat >expected <<-\EOF &&
	main 0x0
	new-main 0x0
	EOF
	test_cmp expected actual
'

test_expect_success 'for_each_ref() is sorted' '
	$RUN for-each-ref refs/heads/ | cut -d" " -f 2- >actual &&
	sort actual > expected &&
	test_cmp expected actual
'

test_expect_success 'resolve_ref(new-main)' '
	SHA1=`shit rev-parse new-main` &&
	echo "$SHA1 refs/heads/new-main 0x0" >expected &&
	$RUN resolve-ref refs/heads/new-main 0 >actual &&
	test_cmp expected actual
'

test_expect_success 'verify_ref(new-main)' '
	$RUN verify-ref refs/heads/new-main
'

test_expect_success 'for_each_reflog()' '
	$RUN for-each-reflog >actual &&
	cat >expected <<-\EOF &&
	HEAD
	refs/heads/main
	refs/heads/new-main
	EOF
	test_cmp expected actual
'

test_expect_success 'for_each_reflog_ent()' '
	$RUN for-each-reflog-ent HEAD >actual &&
	head -n1 actual | grep one &&
	tail -n1 actual | grep recreate-main
'

test_expect_success 'for_each_reflog_ent_reverse()' '
	$RUN for-each-reflog-ent-reverse HEAD >actual &&
	head -n1 actual | grep recreate-main &&
	tail -n1 actual | grep one
'

test_expect_success 'reflog_exists(HEAD)' '
	$RUN reflog-exists HEAD
'

test_expect_success 'delete_reflog(HEAD)' '
	$RUN delete-reflog HEAD &&
	test_must_fail shit reflog exists HEAD
'

test_expect_success 'create-reflog(HEAD)' '
	$RUN create-reflog HEAD &&
	shit reflog exists HEAD
'

test_expect_success 'delete_ref(refs/heads/foo)' '
	shit checkout -b foo &&
	FOO_SHA1=`shit rev-parse foo` &&
	shit checkout --detach &&
	test_commit bar-commit &&
	shit checkout -b bar &&
	BAR_SHA1=`shit rev-parse bar` &&
	$RUN update-ref updating refs/heads/foo $BAR_SHA1 $FOO_SHA1 0 &&
	echo $BAR_SHA1 >expected &&
	shit rev-parse refs/heads/foo >actual &&
	test_cmp expected actual
'

test_expect_success 'delete_ref(refs/heads/foo)' '
	SHA1=`shit rev-parse foo` &&
	shit checkout --detach &&
	$RUN delete-ref msg refs/heads/foo $SHA1 0 &&
	test_must_fail shit rev-parse refs/heads/foo --
'

test_done
