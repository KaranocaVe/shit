#!/bin/sh

test_description='Return value of diffs'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo "1 " >a &&
	shit add . &&
	shit commit -m zeroth &&
	echo 1 >a &&
	shit add . &&
	shit commit -m first &&
	echo 2 >b &&
	shit add . &&
	shit commit -a -m second
'

test_expect_success 'shit diff --quiet -w  HEAD^^ HEAD^' '
	shit diff --quiet -w HEAD^^ HEAD^
'

test_expect_success 'shit diff --quiet HEAD^^ HEAD^' '
	test_must_fail shit diff --quiet HEAD^^ HEAD^
'

test_expect_success 'shit diff --quiet -w  HEAD^ HEAD' '
	test_must_fail shit diff --quiet -w HEAD^ HEAD
'

test_expect_success 'shit diff-tree HEAD^ HEAD' '
	test_expect_code 1 shit diff-tree --exit-code HEAD^ HEAD
'
test_expect_success 'shit diff-tree HEAD^ HEAD -- a' '
	shit diff-tree --exit-code HEAD^ HEAD -- a
'
test_expect_success 'shit diff-tree HEAD^ HEAD -- b' '
	test_expect_code 1 shit diff-tree --exit-code HEAD^ HEAD -- b
'
test_expect_success 'echo HEAD | shit diff-tree --stdin' '
	echo $(shit rev-parse HEAD) | test_expect_code 1 shit diff-tree --exit-code --stdin
'
test_expect_success 'shit diff-tree HEAD HEAD' '
	shit diff-tree --exit-code HEAD HEAD
'
test_expect_success 'shit diff-files' '
	shit diff-files --exit-code
'
test_expect_success 'shit diff-index --cached HEAD' '
	shit diff-index --exit-code --cached HEAD
'
test_expect_success 'shit diff-index --cached HEAD^' '
	test_expect_code 1 shit diff-index --exit-code --cached HEAD^
'
test_expect_success 'shit diff-index --cached HEAD^' '
	echo text >>b &&
	echo 3 >c &&
	shit add . &&
	test_expect_code 1 shit diff-index --exit-code --cached HEAD^
'
test_expect_success 'shit diff-tree -Stext HEAD^ HEAD -- b' '
	shit commit -m "text in b" &&
	test_expect_code 1 shit diff-tree -p --exit-code -Stext HEAD^ HEAD -- b
'
test_expect_success 'shit diff-tree -Snot-found HEAD^ HEAD -- b' '
	shit diff-tree -p --exit-code -Snot-found HEAD^ HEAD -- b
'
test_expect_success 'shit diff-files' '
	echo 3 >>c &&
	test_expect_code 1 shit diff-files --exit-code
'
test_expect_success 'shit diff-index --cached HEAD' '
	shit update-index c &&
	test_expect_code 1 shit diff-index --exit-code --cached HEAD
'

test_expect_success '--check --exit-code returns 0 for no difference' '

	shit diff --check --exit-code

'

test_expect_success '--check --exit-code returns 1 for a clean difference' '

	echo "good" > a &&
	test_expect_code 1 shit diff --check --exit-code

'

test_expect_success '--check --exit-code returns 3 for a dirty difference' '

	echo "bad   " >> a &&
	test_expect_code 3 shit diff --check --exit-code

'

test_expect_success '--check with --no-pager returns 2 for dirty difference' '

	test_expect_code 2 shit --no-pager diff --check

'

test_expect_success 'check should test not just the last line' '
	echo "" >>a &&
	test_expect_code 2 shit --no-pager diff --check

'

test_expect_success 'check detects leftover conflict markers' '
	shit reset --hard &&
	shit checkout HEAD^ &&
	echo binary >>b &&
	shit commit -m "side" b &&
	test_must_fail shit merge main &&
	shit add b &&
	test_expect_code 2 shit --no-pager diff --cached --check >test.out &&
	test 3 = $(grep "conflict marker" test.out | wc -l) &&
	shit reset --hard
'

test_expect_success 'check honors conflict marker length' '
	shit reset --hard &&
	echo ">>>>>>> boo" >>b &&
	echo "======" >>a &&
	shit diff --check a &&
	test_expect_code 2 shit diff --check b &&
	shit reset --hard &&
	echo ">>>>>>>> boo" >>b &&
	echo "========" >>a &&
	shit diff --check &&
	echo "b conflict-marker-size=8" >.shitattributes &&
	test_expect_code 2 shit diff --check b &&
	shit diff --check a &&
	shit reset --hard
'

test_expect_success 'option errors are not confused by --exit-code' '
	test_must_fail shit diff --exit-code --nonsense 2>err &&
	grep '^usage:' err
'

test_done
