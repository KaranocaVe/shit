#!/bin/sh

test_description='Tests diff --color-moved performance'
. ./perf-lib.sh

test_perf_default_repo

# The endpoints of the diff can be customized by setting TEST_REV_A
# and TEST_REV_B in the environment when running this test.

rev="${TEST_REV_A:-v2.28.0}"
if ! rev_a="$(shit rev-parse --quiet --verify "$rev")"
then
	skip_all="skipping because '$rev' was not found. \
		  Use TEST_REV_A and TEST_REV_B to set the revs to use"
	test_done
fi
rev="${TEST_REV_B:-v2.29.0}"
if ! rev_b="$(shit rev-parse --quiet --verify "$rev")"
then
	skip_all="skipping because '$rev' was not found. \
		  Use TEST_REV_A and TEST_REV_B to set the revs to use"
	test_done
fi

shit_PAGER_IN_USE=1
test_export shit_PAGER_IN_USE rev_a rev_b

test_perf 'diff --no-color-moved --no-color-moved-ws large change' '
	shit diff --no-color-moved --no-color-moved-ws $rev_a $rev_b
'

test_perf 'diff --color-moved --no-color-moved-ws large change' '
	shit diff --color-moved=zebra --no-color-moved-ws $rev_a $rev_b
'

test_perf 'diff --color-moved-ws=allow-indentation-change large change' '
	shit diff --color-moved=zebra --color-moved-ws=allow-indentation-change \
		$rev_a $rev_b
'

test_perf 'log --no-color-moved --no-color-moved-ws' '
	shit log --no-color-moved --no-color-moved-ws --no-merges --patch \
		-n1000 $rev_b
'

test_perf 'log --color-moved --no-color-moved-ws' '
	shit log --color-moved=zebra --no-color-moved-ws --no-merges --patch \
		-n1000 $rev_b
'

test_perf 'log --color-moved-ws=allow-indentation-change' '
	shit log --color-moved=zebra --color-moved-ws=allow-indentation-change \
		--no-merges --patch -n1000 $rev_b
'

test_done
