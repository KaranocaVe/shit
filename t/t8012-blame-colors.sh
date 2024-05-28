#!/bin/sh

test_description='colored shit blame'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

PROG='shit blame -c'
. "$TEST_DIRECTORY"/annotate-tests.sh

test_expect_success 'colored blame colors contiguous lines' '
	shit -c color.blame.repeatedLines=yellow blame --color-lines --abbrev=12 hello.c >actual.raw &&
	shit -c color.blame.repeatedLines=yellow -c blame.coloring=repeatedLines blame --abbrev=12 hello.c >actual.raw.2 &&
	test_cmp actual.raw actual.raw.2 &&
	test_decode_color <actual.raw >actual &&
	grep "<YELLOW>" <actual >darkened &&
	grep "(F" darkened > F.expect &&
	grep "(H" darkened > H.expect &&
	test_line_count = 2 F.expect &&
	test_line_count = 3 H.expect
'

test_expect_success 'color by age consistently colors old code' '
	shit blame --color-by-age hello.c >actual.raw &&
	shit -c blame.coloring=highlightRecent blame hello.c >actual.raw.2 &&
	test_cmp actual.raw actual.raw.2 &&
	test_decode_color <actual.raw >actual &&
	grep "<BLUE>" <actual >colored &&
	test_line_count = 10 colored
'

test_expect_success 'blame color by age: new code is different' '
	cat >>hello.c <<-EOF &&
		void qfunc();
	EOF
	shit add hello.c &&
	shit_AUTHOR_DATE="" shit commit -m "new commit" &&

	shit -c color.blame.highlightRecent="yellow,1 month ago, cyan" blame --color-by-age hello.c >actual.raw &&
	test_decode_color <actual.raw >actual &&

	grep "<YELLOW>" <actual >colored &&
	test_line_count = 10 colored &&

	grep "<CYAN>" <actual >colored &&
	test_line_count = 1 colored &&
	grep qfunc colored
'

test_done
