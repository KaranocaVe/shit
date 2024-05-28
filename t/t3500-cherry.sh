#!/bin/sh
#
# Copyright (c) 2006 Yann Dirson, based on t3400 by Amos Waterland
#

test_description='shit cherry should detect patches integrated upstream

This test cherry-picks one local change of two into main branch, and
checks that shit cherry only returns the second patch in the local branch
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

shit_AUTHOR_EMAIL=bogus_email_address
export shit_AUTHOR_EMAIL

test_expect_success 'prepare repository with topic branch, and check cherry finds the 2 patches from there' '
	echo First > A &&
	shit update-index --add A &&
	test_tick &&
	shit commit -m "Add A." &&

	shit checkout -b my-topic-branch &&

	echo Second > B &&
	shit update-index --add B &&
	test_tick &&
	shit commit -m "Add B." &&

	echo AnotherSecond > C &&
	shit update-index --add C &&
	test_tick &&
	shit commit -m "Add C." &&

	shit checkout -f main &&
	rm -f B C &&

	echo Third >> A &&
	shit update-index A &&
	test_tick &&
	shit commit -m "Modify A." &&

	expr "$(echo $(shit cherry main my-topic-branch) )" : "+ [^ ]* + .*"
'

test_expect_success 'check that cherry with limit returns only the top patch' '
	expr "$(echo $(shit cherry main my-topic-branch my-topic-branch^1) )" : "+ [^ ]*"
'

test_expect_success 'cherry-pick one of the 2 patches, and check cherry recognized one and only one as new' '
	shit cherry-pick my-topic-branch^0 &&
	echo $(shit cherry main my-topic-branch) &&
	expr "$(echo $(shit cherry main my-topic-branch) )" : "+ [^ ]* - .*"
'

test_expect_success 'cherry ignores whitespace' '
	shit switch --orphan=upstream-with-space &&
	test_commit initial file &&
	>expect &&
	shit switch --create=feature-without-space &&

	# A spaceless file on the feature branch.  Expect a match upstream.
	printf space >file &&
	shit add file &&
	shit commit -m"file without space" &&
	shit log --format="- %H" -1 >>expect &&

	# A further change.  Should not match upstream.
	test_commit change file &&
	shit log --format="+ %H" -1 >>expect &&

	shit switch upstream-with-space &&
	# Same as the spaceless file, just with spaces and on upstream.
	test_commit "file with space" file "s p a c e" file-with-space &&
	shit cherry upstream-with-space feature-without-space >actual &&
	test_cmp expect actual
'

test_done
