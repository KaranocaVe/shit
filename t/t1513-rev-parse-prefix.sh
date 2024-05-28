#!/bin/sh

test_description='Tests for rev-parse --prefix'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir -p sub1/sub2 &&
	echo top >top &&
	echo file1 >sub1/file1 &&
	echo file2 >sub1/sub2/file2 &&
	shit add top sub1/file1 sub1/sub2/file2 &&
	shit commit -m commit
'

test_expect_success 'empty prefix -- file' '
	shit rev-parse --prefix "" -- top sub1/file1 >actual &&
	cat <<-\EOF >expected &&
	--
	top
	sub1/file1
	EOF
	test_cmp expected actual
'

test_expect_success 'valid prefix -- file' '
	shit rev-parse --prefix sub1/ -- file1 sub2/file2 >actual &&
	cat <<-\EOF >expected &&
	--
	sub1/file1
	sub1/sub2/file2
	EOF
	test_cmp expected actual
'

test_expect_success 'valid prefix -- ../file' '
	shit rev-parse --prefix sub1/ -- ../top sub2/file2 >actual &&
	cat <<-\EOF >expected &&
	--
	sub1/../top
	sub1/sub2/file2
	EOF
	test_cmp expected actual
'

test_expect_success 'empty prefix HEAD:./path' '
	shit rev-parse --prefix "" HEAD:./top >actual &&
	shit rev-parse HEAD:top >expected &&
	test_cmp expected actual
'

test_expect_success 'valid prefix HEAD:./path' '
	shit rev-parse --prefix sub1/ HEAD:./file1 >actual &&
	shit rev-parse HEAD:sub1/file1 >expected &&
	test_cmp expected actual
'

test_expect_success 'valid prefix HEAD:../path' '
	shit rev-parse --prefix sub1/ HEAD:../top >actual &&
	shit rev-parse HEAD:top >expected &&
	test_cmp expected actual
'

test_expect_success 'prefix ignored with HEAD:top' '
	shit rev-parse --prefix sub1/ HEAD:top >actual &&
	shit rev-parse HEAD:top >expected &&
	test_cmp expected actual
'

test_expect_success 'disambiguate path with valid prefix' '
	shit rev-parse --prefix sub1/ file1 >actual &&
	cat <<-\EOF >expected &&
	sub1/file1
	EOF
	test_cmp expected actual
'

test_expect_success 'file and refs with prefix' '
	shit rev-parse --prefix sub1/ main file1 >actual &&
	cat <<-EOF >expected &&
	$(shit rev-parse main)
	sub1/file1
	EOF
	test_cmp expected actual
'

test_expect_success 'two-levels deep' '
	shit rev-parse --prefix sub1/sub2/ -- file2 >actual &&
	cat <<-\EOF >expected &&
	--
	sub1/sub2/file2
	EOF
	test_cmp expected actual
'

test_done
