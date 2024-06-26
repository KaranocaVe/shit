#!/bin/sh

test_description='Test commands behavior when given invalid argument value'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup ' '
	test_commit "v1.0"
'

test_expect_success 'tag --contains <existent_tag>' '
	shit tag --contains "v1.0" >actual 2>actual.err &&
	grep "v1.0" actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'tag --contains <inexistent_tag>' '
	test_must_fail shit tag --contains "notag" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'tag --no-contains <existent_tag>' '
	shit tag --no-contains "v1.0" >actual 2>actual.err  &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'tag --no-contains <inexistent_tag>' '
	test_must_fail shit tag --no-contains "notag" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'tag usage error' '
	test_must_fail shit tag --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "usage" actual.err
'

test_expect_success 'branch --contains <existent_commit>' '
	shit branch --contains "main" >actual 2>actual.err &&
	test_grep "main" actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'branch --contains <inexistent_commit>' '
	test_must_fail shit branch --no-contains "nocommit" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'branch --no-contains <existent_commit>' '
	shit branch --no-contains "main" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'branch --no-contains <inexistent_commit>' '
	test_must_fail shit branch --no-contains "nocommit" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'branch usage error' '
	test_must_fail shit branch --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "usage" actual.err
'

test_expect_success 'for-each-ref --contains <existent_object>' '
	shit for-each-ref --contains "main" >actual 2>actual.err &&
	test_line_count = 2 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'for-each-ref --contains <inexistent_object>' '
	test_must_fail shit for-each-ref --no-contains "noobject" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'for-each-ref --no-contains <existent_object>' '
	shit for-each-ref --no-contains "main" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_line_count = 0 actual.err
'

test_expect_success 'for-each-ref --no-contains <inexistent_object>' '
	test_must_fail shit for-each-ref --no-contains "noobject" >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "error" actual.err &&
	test_grep ! "usage" actual.err
'

test_expect_success 'for-each-ref usage error' '
	test_must_fail shit for-each-ref --noopt >actual 2>actual.err &&
	test_line_count = 0 actual &&
	test_grep "usage" actual.err
'

test_done
