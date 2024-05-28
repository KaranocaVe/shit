#!/bin/sh

test_description='merge with sparse files'

TEST_CREATE_REPO_NO_TEMPLATE=1
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# test_file $filename $content
test_file () {
	echo "$2" > "$1" &&
	shit add "$1"
}

# test_commit_this $message_and_tag
test_commit_this () {
	shit commit -m "$1" &&
	shit tag "$1"
}

test_expect_success 'setup' '
	test_file checked-out init &&
	test_file modify_delete modify_delete_init &&
	test_commit_this init &&
	test_file modify_delete modify_delete_theirs &&
	test_commit_this theirs &&
	shit reset --hard init &&
	shit rm modify_delete &&
	test_commit_this ours &&
	shit config core.sparseCheckout true &&
	mkdir .shit/info &&
	echo "/checked-out" >.shit/info/sparse-checkout &&
	shit reset --hard &&
	test_must_fail shit merge theirs
'

test_expect_success 'reset --hard works after the conflict' '
	shit reset --hard
'

test_expect_success 'is reset properly' '
	shit status --porcelain -- modify_delete >out &&
	test_must_be_empty out &&
	test_path_is_missing modify_delete
'

test_expect_success 'setup: conflict back' '
	test_must_fail shit merge theirs
'

test_expect_success 'Merge abort works after the conflict' '
	shit merge --abort
'

test_expect_success 'is aborted properly' '
	shit status --porcelain -- modify_delete >out &&
	test_must_be_empty out &&
	test_path_is_missing modify_delete
'

test_done
