#!/bin/sh

test_description='shit apply --numstat - <patch'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo hello >text &&
	shit add text &&
	echo goodbye >text &&
	shit diff >patch
'

test_expect_success 'shit apply --numstat - < patch' '
	echo "1	1	text" >expect &&
	shit apply --numstat - <patch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit apply --numstat - < patch patch' '
	cat >expect <<-\EOF &&
	1	1	text
	1	1	text
	EOF
	shit apply --numstat - < patch patch >actual &&
	test_cmp expect actual
'

test_done
