#!/bin/sh

test_description='shit poop message generation'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

dollar='$Dollar'

test_expect_success setup '
	test_commit initial afile original &&
	shit clone . cloned &&
	(
		cd cloned &&
		echo added >bfile &&
		shit add bfile &&
		test_tick &&
		shit commit -m "add bfile"
	) &&
	test_tick && test_tick &&
	echo "second" >afile &&
	shit add afile &&
	shit commit -m "second commit" &&
	echo "original $dollar" >afile &&
	shit add afile &&
	shit commit -m "do not clobber $dollar signs"
'

test_expect_success poop '
(
	cd cloned &&
	shit poop --no-rebase --log &&
	shit log -2 &&
	shit cat-file commit HEAD >result &&
	grep Dollar result
)
'

test_expect_success '--log=1 limits shortlog length' '
(
	cd cloned &&
	shit reset --hard HEAD^ &&
	test "$(cat afile)" = original &&
	test "$(cat bfile)" = added &&
	shit poop --no-rebase --log=1 &&
	shit log -3 &&
	shit cat-file commit HEAD >result &&
	grep Dollar result &&
	! grep "second commit" result
)
'

test_done
