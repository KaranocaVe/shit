#!/bin/sh

test_description='shit log with filter options limiting the output'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup test' '
	shit init &&
	echo a >file &&
	shit add file &&
	shit_COMMITTER_DATE="2021-02-01 00:00" shit commit -m init &&
	echo a >>file &&
	shit add file &&
	shit_COMMITTER_DATE="2022-02-01 00:00" shit commit -m first &&
	echo a >>file &&
	shit add file &&
	shit_COMMITTER_DATE="2021-03-01 00:00" shit commit -m second &&
	echo a >>file &&
	shit add file &&
	shit_COMMITTER_DATE="2022-03-01 00:00" shit commit -m third
'

test_expect_success 'shit log --since-as-filter=...' '
	shit log --since-as-filter="2022-01-01" --format=%s >actual &&
	cat >expect <<-\EOF &&
	third
	first
	EOF
	test_cmp expect actual
'

test_expect_success 'shit log --children --since-as-filter=...' '
	shit log --children --since-as-filter="2022-01-01" --format=%s >actual &&
	cat >expect <<-\EOF &&
	third
	first
	EOF
	test_cmp expect actual
'

test_done
