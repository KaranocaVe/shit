#!/bin/sh

test_description='merge: handle file mode'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up mode change in one branch' '
	: >file1 &&
	shit add file1 &&
	shit commit -m initial &&
	shit checkout -b a1 main &&
	: >dummy &&
	shit add dummy &&
	shit commit -m a &&
	shit checkout -b b1 main &&
	test_chmod +x file1 &&
	shit add file1 &&
	shit commit -m b1
'

do_one_mode () {
	strategy=$1
	us=$2
	them=$3
	test_expect_success "resolve single mode change ($strategy, $us)" '
		shit checkout -f $us &&
		shit merge -s $strategy $them &&
		shit ls-files -s file1 | grep ^100755
	'

	test_expect_success FILEMODE "verify executable bit on file ($strategy, $us)" '
		test -x file1
	'
}

do_one_mode recursive a1 b1
do_one_mode recursive b1 a1
do_one_mode resolve a1 b1
do_one_mode resolve b1 a1

test_expect_success 'set up mode change in both branches' '
	shit reset --hard HEAD &&
	shit checkout -b a2 main &&
	: >file2 &&
	H=$(shit hash-object file2) &&
	test_chmod +x file2 &&
	shit commit -m a2 &&
	shit checkout -b b2 main &&
	: >file2 &&
	shit add file2 &&
	shit commit -m b2 &&
	cat >expect <<-EOF
	100755 $H 2	file2
	100644 $H 3	file2
	EOF
'

do_both_modes () {
	strategy=$1
	test_expect_success "detect conflict on double mode change ($strategy)" '
		shit reset --hard &&
		shit checkout -f a2 &&
		test_must_fail shit merge -s $strategy b2 &&
		shit ls-files -u >actual &&
		test_cmp expect actual &&
		shit ls-files -s file2 | grep ^100755
	'

	test_expect_success FILEMODE "verify executable bit on file ($strategy)" '
		test -x file2
	'
}

# both sides are equivalent, so no need to run both ways
do_both_modes recursive
do_both_modes resolve

test_expect_success 'set up delete/modechange scenario' '
	shit reset --hard &&
	shit checkout -b deletion main &&
	shit rm file1 &&
	shit commit -m deletion
'

do_delete_modechange () {
	strategy=$1
	us=$2
	them=$3
	test_expect_success "detect delete/modechange conflict ($strategy, $us)" '
		shit reset --hard &&
		shit checkout $us &&
		test_must_fail shit merge -s $strategy $them
	'
}

do_delete_modechange recursive b1 deletion
do_delete_modechange recursive deletion b1
do_delete_modechange resolve b1 deletion
do_delete_modechange resolve deletion b1

test_done
