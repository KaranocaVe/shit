#!/bin/sh

test_description='rerere run in a workdir'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success SYMLINKS setup '
	shit config rerere.enabled true &&
	>world &&
	shit add world &&
	test_tick &&
	shit commit -m initial &&

	echo hello >world &&
	test_tick &&
	shit commit -a -m hello &&

	shit checkout -b side HEAD^ &&
	echo goodbye >world &&
	test_tick &&
	shit commit -a -m goodbye &&

	shit checkout main
'

test_expect_success SYMLINKS 'rerere in workdir' '
	rm -rf .shit/rr-cache &&
	"$SHELL_PATH" "$TEST_DIRECTORY/../contrib/workdir/shit-new-workdir" . work &&
	(
		cd work &&
		test_must_fail shit merge side &&
		shit rerere status >actual &&
		echo world >expect &&
		test_cmp expect actual
	)
'

# This fails because we don't resolve relative symlink in mkdir_in_shitdir()
# For the purpose of helping contrib/workdir/shit-new-workdir users, we do not
# have to support relative symlinks, but it might be nicer to make this work
# with a relative symbolic link someday.
test_expect_failure SYMLINKS 'rerere in workdir (relative)' '
	rm -rf .shit/rr-cache &&
	"$SHELL_PATH" "$TEST_DIRECTORY/../contrib/workdir/shit-new-workdir" . krow &&
	(
		cd krow &&
		rm -f .shit/rr-cache &&
		ln -s ../.shit/rr-cache .shit/rr-cache &&
		test_must_fail shit merge side &&
		shit rerere status >actual &&
		echo world >expect &&
		test_cmp expect actual
	)
'

test_done
