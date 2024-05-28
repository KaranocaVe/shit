#!/bin/sh

test_description='pre-commit and pre-merge-commit hooks'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'root commit' '
	echo "root" >file &&
	shit add file &&
	shit commit -m "zeroth" &&
	shit checkout -b side &&
	echo "foo" >foo &&
	shit add foo &&
	shit commit -m "make it non-ff" &&
	shit branch side-orig side &&
	shit checkout main
'

test_expect_success 'setup conflicting branches' '
	test_when_finished "shit checkout main" &&
	shit checkout -b conflicting-a main &&
	echo a >conflicting &&
	shit add conflicting &&
	shit commit -m conflicting-a &&
	shit checkout -b conflicting-b main &&
	echo b >conflicting &&
	shit add conflicting &&
	shit commit -m conflicting-b
'

test_expect_success 'with no hook' '
	test_when_finished "rm -f actual_hooks" &&
	echo "foo" >file &&
	shit add file &&
	shit commit -m "first" &&
	test_path_is_missing actual_hooks
'

test_expect_success 'with no hook (merge)' '
	test_when_finished "rm -f actual_hooks" &&
	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

test_expect_success '--no-verify with no hook' '
	test_when_finished "rm -f actual_hooks" &&
	echo "bar" >file &&
	shit add file &&
	shit commit --no-verify -m "bar" &&
	test_path_is_missing actual_hooks
'

test_expect_success '--no-verify with no hook (merge)' '
	test_when_finished "rm -f actual_hooks" &&
	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge --no-verify -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

setup_success_hook () {
	test_when_finished "rm -f actual_hooks expected_hooks" &&
	echo "$1" >expected_hooks &&
	test_hook "$1" <<-EOF
	echo $1 >>actual_hooks
	EOF
}

test_expect_success 'with succeeding hook' '
	setup_success_hook "pre-commit" &&
	echo "more" >>file &&
	shit add file &&
	shit commit -m "more" &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success 'with succeeding hook (merge)' '
	setup_success_hook "pre-merge-commit" &&
	shit checkout side &&
	shit merge -m "merge main" main &&
	shit checkout main &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success 'automatic merge fails; both hooks are available' '
	setup_success_hook "pre-commit" &&
	setup_success_hook "pre-merge-commit" &&

	shit checkout conflicting-a &&
	test_must_fail shit merge -m "merge conflicting-b" conflicting-b &&
	test_path_is_missing actual_hooks &&

	echo "pre-commit" >expected_hooks &&
	echo a+b >conflicting &&
	shit add conflicting &&
	shit commit -m "resolve conflict" &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success '--no-verify with succeeding hook' '
	setup_success_hook "pre-commit" &&
	echo "even more" >>file &&
	shit add file &&
	shit commit --no-verify -m "even more" &&
	test_path_is_missing actual_hooks
'

test_expect_success '--no-verify with succeeding hook (merge)' '
	setup_success_hook "pre-merge-commit" &&
	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge --no-verify -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

setup_failing_hook () {
	test_when_finished "rm -f actual_hooks" &&
	test_hook "$1" <<-EOF
	echo $1-failing-hook >>actual_hooks
	exit 1
	EOF
}

test_expect_success 'with failing hook' '
	setup_failing_hook "pre-commit" &&
	test_when_finished "rm -f expected_hooks" &&
	echo "pre-commit-failing-hook" >expected_hooks &&

	echo "another" >>file &&
	shit add file &&
	test_must_fail shit commit -m "another" &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success '--no-verify with failing hook' '
	setup_failing_hook "pre-commit" &&
	echo "stuff" >>file &&
	shit add file &&
	shit commit --no-verify -m "stuff" &&
	test_path_is_missing actual_hooks
'

test_expect_success 'with failing hook (merge)' '
	setup_failing_hook "pre-merge-commit" &&
	echo "pre-merge-commit-failing-hook" >expected_hooks &&
	shit checkout side &&
	test_must_fail shit merge -m "merge main" main &&
	shit checkout main &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success '--no-verify with failing hook (merge)' '
	setup_failing_hook "pre-merge-commit" &&

	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge --no-verify -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

setup_non_exec_hook () {
	test_when_finished "rm -f actual_hooks" &&
	test_hook "$1" <<-\EOF &&
	echo non-exec >>actual_hooks
	exit 1
	EOF
	test_hook --disable "$1"
}


test_expect_success POSIXPERM 'with non-executable hook' '
	setup_non_exec_hook "pre-commit" &&
	echo "content" >>file &&
	shit add file &&
	shit commit -m "content" &&
	test_path_is_missing actual_hooks
'

test_expect_success POSIXPERM '--no-verify with non-executable hook' '
	setup_non_exec_hook "pre-commit" &&
	echo "more content" >>file &&
	shit add file &&
	shit commit --no-verify -m "more content" &&
	test_path_is_missing actual_hooks
'

test_expect_success POSIXPERM 'with non-executable hook (merge)' '
	setup_non_exec_hook "pre-merge" &&
	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

test_expect_success POSIXPERM '--no-verify with non-executable hook (merge)' '
	setup_non_exec_hook "pre-merge" &&
	shit branch -f side side-orig &&
	shit checkout side &&
	shit merge --no-verify -m "merge main" main &&
	shit checkout main &&
	test_path_is_missing actual_hooks
'

setup_require_prefix_hook () {
	test_when_finished "rm -f expected_hooks" &&
	echo require-prefix >expected_hooks &&
	test_hook pre-commit <<-\EOF
	echo require-prefix >>actual_hooks
	test $shit_PREFIX = "success/"
	EOF
}

test_expect_success 'with hook requiring shit_PREFIX' '
	test_when_finished "rm -rf actual_hooks success" &&
	setup_require_prefix_hook &&
	echo "more content" >>file &&
	shit add file &&
	mkdir success &&
	(
		cd success &&
		shit commit -m "hook requires shit_PREFIX = success/"
	) &&
	test_cmp expected_hooks actual_hooks
'

test_expect_success 'with failing hook requiring shit_PREFIX' '
	test_when_finished "rm -rf actual_hooks fail" &&
	setup_require_prefix_hook &&
	echo "more content" >>file &&
	shit add file &&
	mkdir fail &&
	(
		cd fail &&
		test_must_fail shit commit -m "hook must fail"
	) &&
	shit checkout -- file &&
	test_cmp expected_hooks actual_hooks
'

setup_require_author_hook () {
	test_when_finished "rm -f expected_hooks actual_hooks" &&
	echo check-author >expected_hooks &&
	test_hook pre-commit <<-\EOF
	echo check-author >>actual_hooks
	test "$shit_AUTHOR_NAME" = "New Author" &&
	test "$shit_AUTHOR_EMAIL" = "newauthor@example.com"
	EOF
}


test_expect_success 'check the author in hook' '
	setup_require_author_hook &&
	cat >expected_hooks <<-EOF &&
	check-author
	check-author
	check-author
	EOF
	test_must_fail shit commit --allow-empty -m "by a.u.thor" &&
	(
		shit_AUTHOR_NAME="New Author" &&
		shit_AUTHOR_EMAIL="newauthor@example.com" &&
		export shit_AUTHOR_NAME shit_AUTHOR_EMAIL &&
		shit commit --allow-empty -m "by new.author via env" &&
		shit show -s
	) &&
	shit commit --author="New Author <newauthor@example.com>" \
		--allow-empty -m "by new.author via command line" &&
	shit show -s &&
	test_cmp expected_hooks actual_hooks
'

test_done
