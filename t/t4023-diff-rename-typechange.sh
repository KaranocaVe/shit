#!/bin/sh

test_description='typechange rename detection'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff.sh

test_expect_success setup '

	rm -f foo bar &&
	COPYING_test_data >foo &&
	test_ln_s_add linklink bar &&
	shit add foo &&
	shit commit -a -m Initial &&
	shit tag one &&

	shit rm -f foo bar &&
	COPYING_test_data >bar &&
	test_ln_s_add linklink foo &&
	shit add bar &&
	shit commit -a -m Second &&
	shit tag two &&

	shit rm -f foo bar &&
	COPYING_test_data >foo &&
	shit add foo &&
	shit commit -a -m Third &&
	shit tag three &&

	mv foo bar &&
	test_ln_s_add linklink foo &&
	shit add bar &&
	shit commit -a -m Fourth &&
	shit tag four &&

	# This is purely for sanity check

	shit rm -f foo bar &&
	COPYING_test_data >foo &&
	cat "$TEST_DIRECTORY"/../Makefile >bar &&
	shit add foo bar &&
	shit commit -a -m Fifth &&
	shit tag five &&

	shit rm -f foo bar &&
	cat "$TEST_DIRECTORY"/../Makefile >foo &&
	COPYING_test_data >bar &&
	shit add foo bar &&
	shit commit -a -m Sixth &&
	shit tag six

'

test_expect_success 'cross renames to be detected for regular files' '
	shit diff-tree five six -r --name-status -B -M >out &&
	sort out >actual &&
	{
		echo "R100	foo	bar" &&
		echo "R100	bar	foo"
	} | sort >expect &&
	test_cmp expect actual

'

test_expect_success 'cross renames to be detected for typechange' '
	shit diff-tree one two -r --name-status -B -M >out &&
	sort out >actual &&
	{
		echo "R100	foo	bar" &&
		echo "R100	bar	foo"
	} | sort >expect &&
	test_cmp expect actual

'

test_expect_success 'moves and renames' '
	shit diff-tree three four -r --name-status -B -M >out &&
	sort out >actual &&
	{
		# see -B -M (#6) in t4008
		echo "C100	foo	bar" &&
		echo "T100	foo"
	} | sort >expect &&
	test_cmp expect actual

'

test_done
