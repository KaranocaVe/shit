#!/bin/sh

test_description='diff --exit-code with whitespace'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	mkdir a b &&
	echo >c &&
	echo >a/d &&
	echo >b/e &&
	shit add . &&
	test_tick &&
	shit commit -m initial &&
	echo " " >a/d &&
	test_tick &&
	shit commit -a -m second &&
	echo "  " >a/d &&
	echo " " >b/e &&
	shit add a/d
'

test_expect_success 'diff-tree --exit-code' '
	test_must_fail shit diff --exit-code HEAD^ HEAD &&
	test_must_fail shit diff-tree --exit-code HEAD^ HEAD
'

test_expect_success 'diff-tree -b --exit-code' '
	shit diff -b --exit-code HEAD^ HEAD &&
	shit diff-tree -b -p --exit-code HEAD^ HEAD
'

test_expect_success 'diff-index --cached --exit-code' '
	test_must_fail shit diff --cached --exit-code HEAD &&
	test_must_fail shit diff-index --cached --exit-code HEAD
'

test_expect_success 'diff-index -b -p --cached --exit-code' '
	shit diff -b --cached --exit-code HEAD &&
	shit diff-index -b -p --cached --exit-code HEAD
'

test_expect_success 'diff-index --exit-code' '
	test_must_fail shit diff --exit-code HEAD &&
	test_must_fail shit diff-index --exit-code HEAD
'

test_expect_success 'diff-index -b -p --exit-code' '
	shit diff -b --exit-code HEAD &&
	shit diff-index -b -p --exit-code HEAD
'

test_expect_success 'diff-files --exit-code' '
	test_must_fail shit diff --exit-code &&
	test_must_fail shit diff-files --exit-code
'

test_expect_success 'diff-files -b -p --exit-code' '
	shit diff -b --exit-code &&
	shit diff-files -b -p --exit-code
'

test_expect_success 'diff-files --diff-filter --quiet' '
	shit reset --hard &&
	rm a/d &&
	echo x >>b/e &&
	test_must_fail shit diff-files --diff-filter=M --quiet
'

test_expect_success 'diff-tree --diff-filter --quiet' '
	shit commit -a -m "worktree state" &&
	test_must_fail shit diff-tree --diff-filter=M --quiet HEAD^ HEAD
'

test_done
