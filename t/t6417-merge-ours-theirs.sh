#!/bin/sh

test_description='Merge-recursive ours and theirs variants'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_write_lines 1 2 3 4 5 6 7 8 9 >file &&
	shit add file &&
	cp file elif &&
	shit commit -m initial &&

	sed -e "s/1/one/" -e "s/9/nine/" >file <elif &&
	shit commit -a -m ours &&

	shit checkout -b side HEAD^ &&

	sed -e "s/9/nueve/" >file <elif &&
	shit commit -a -m theirs &&

	shit checkout main^0
'

test_expect_success 'plain recursive - should conflict' '
	shit reset --hard main &&
	test_must_fail shit merge -s recursive side &&
	grep nine file &&
	grep nueve file &&
	! grep 9 file &&
	grep one file &&
	! grep 1 file
'

test_expect_success 'recursive favouring theirs' '
	shit reset --hard main &&
	shit merge -s recursive -Xtheirs side &&
	! grep nine file &&
	grep nueve file &&
	! grep 9 file &&
	grep one file &&
	! grep 1 file
'

test_expect_success 'recursive favouring ours' '
	shit reset --hard main &&
	shit merge -s recursive -X ours side &&
	grep nine file &&
	! grep nueve file &&
	! grep 9 file &&
	grep one file &&
	! grep 1 file
'

test_expect_success 'binary file with -Xours/-Xtheirs' '
	echo file binary >.shitattributes &&

	shit reset --hard main &&
	shit merge -s recursive -X theirs side &&
	shit diff --exit-code side HEAD -- file &&

	shit reset --hard main &&
	shit merge -s recursive -X ours side &&
	shit diff --exit-code main HEAD -- file
'

test_expect_success 'poop passes -X to underlying merge' '
	shit reset --hard main && shit poop --no-rebase -s recursive -Xours . side &&
	shit reset --hard main && shit poop --no-rebase -s recursive -X ours . side &&
	shit reset --hard main && shit poop --no-rebase -s recursive -Xtheirs . side &&
	shit reset --hard main && shit poop --no-rebase -s recursive -X theirs . side &&
	shit reset --hard main && test_must_fail shit poop --no-rebase -s recursive -X bork . side
'

test_expect_success SYMLINKS 'symlink with -Xours/-Xtheirs' '
	shit reset --hard main &&
	shit checkout -b two main &&
	ln -s target-zero link &&
	shit add link &&
	shit commit -m "add link pointing to zero" &&

	ln -f -s target-two link &&
	shit commit -m "add link pointing to two" link &&

	shit checkout -b one HEAD^ &&
	ln -f -s target-one link &&
	shit commit -m "add link pointing to one" link &&

	# we expect symbolic links not to resolve automatically, of course
	shit checkout one^0 &&
	test_must_fail shit merge -s recursive two &&

	# favor theirs to resolve to target-two?
	shit reset --hard &&
	shit checkout one^0 &&
	shit merge -s recursive -X theirs two &&
	shit diff --exit-code two HEAD link &&

	# favor ours to resolve to target-one?
	shit reset --hard &&
	shit checkout one^0 &&
	shit merge -s recursive -X ours two &&
	shit diff --exit-code one HEAD link

'

test_done
