#!/bin/sh

test_description='ask merge-recursive to merge binary files'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	cat "$TEST_DIRECTORY"/test-binary-1.png >m &&
	shit add m &&
	shit ls-files -s | sed -e "s/ 0	/ 1	/" >E1 &&
	test_tick &&
	shit commit -m "initial" &&

	shit branch side &&
	echo frotz >a &&
	shit add a &&
	echo nitfol >>m &&
	shit add a m &&
	shit ls-files -s a >E0 &&
	shit ls-files -s m | sed -e "s/ 0	/ 3	/" >E3 &&
	test_tick &&
	shit commit -m "main adds some" &&

	shit checkout side &&
	echo rezrov >>m &&
	shit add m &&
	shit ls-files -s m | sed -e "s/ 0	/ 2	/" >E2 &&
	test_tick &&
	shit commit -m "side modifies" &&

	shit tag anchor &&

	cat E0 E1 E2 E3 >expect
'

test_expect_success resolve '

	rm -f a* m* &&
	shit reset --hard anchor &&

	test_must_fail shit merge -s resolve main &&
	shit ls-files -s >current &&
	test_cmp expect current
'

test_expect_success recursive '

	rm -f a* m* &&
	shit reset --hard anchor &&

	test_must_fail shit merge -s recursive main &&
	shit ls-files -s >current &&
	test_cmp expect current
'

test_done
