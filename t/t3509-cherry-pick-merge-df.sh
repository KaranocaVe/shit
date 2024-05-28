#!/bin/sh

test_description='Test cherry-pick with directory/file conflicts'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'Initialize repository' '
	mkdir a &&
	>a/f &&
	shit add a &&
	shit commit -m a
'

test_expect_success 'Setup rename across paths each below D/F conflicts' '
	mkdir b &&
	test_ln_s_add ../a b/a &&
	shit commit -m b &&

	shit checkout -b branch &&
	rm b/a &&
	shit mv a b/a &&
	test_ln_s_add b/a a &&
	shit commit -m swap &&

	>f1 &&
	shit add f1 &&
	shit commit -m f1
'

test_expect_success 'Cherry-pick succeeds with rename across D/F conflicts' '
	shit reset --hard &&
	shit checkout main^0 &&
	shit cherry-pick branch
'

test_expect_success 'Setup rename with file on one side matching directory name on other' '
	shit checkout --orphan nick-testcase &&
	shit rm -rf . &&

	>empty &&
	shit add empty &&
	shit commit -m "Empty file" &&

	shit checkout -b simple &&
	mv empty file &&
	mkdir empty &&
	mv file empty &&
	shit add empty/file &&
	shit commit -m "Empty file under empty dir" &&

	echo content >newfile &&
	shit add newfile &&
	shit commit -m "New file"
'

test_expect_success 'Cherry-pick succeeds with was_a_dir/file -> was_a_dir (resolve)' '
	shit reset --hard &&
	shit checkout -q nick-testcase^0 &&
	shit cherry-pick --strategy=resolve simple
'

test_expect_success 'Cherry-pick succeeds with was_a_dir/file -> was_a_dir (recursive)' '
	shit reset --hard &&
	shit checkout -q nick-testcase^0 &&
	shit cherry-pick --strategy=recursive simple
'

test_expect_success 'Setup rename with file on one side matching different dirname on other' '
	shit reset --hard &&
	shit checkout --orphan mergeme &&
	shit rm -rf . &&

	mkdir sub &&
	mkdir othersub &&
	echo content > sub/file &&
	echo foo > othersub/whatever &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit rm -rf othersub &&
	shit mv sub/file othersub &&
	shit commit -m "Commit to merge" &&

	shit checkout -b newhead mergeme~1 &&
	>independent-change &&
	shit add independent-change &&
	shit commit -m "Completely unrelated change"
'

test_expect_success 'Cherry-pick with rename to different D/F conflict succeeds (resolve)' '
	shit reset --hard &&
	shit checkout -q newhead^0 &&
	shit cherry-pick --strategy=resolve mergeme
'

test_expect_success 'Cherry-pick with rename to different D/F conflict succeeds (recursive)' '
	shit reset --hard &&
	shit checkout -q newhead^0 &&
	shit cherry-pick --strategy=recursive mergeme
'

test_done
