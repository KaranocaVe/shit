#!/bin/sh

test_description='reflog walk shows repeated commits again'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup commits' '
	test_commit one file content &&
	test_commit --append two file content
'

test_expect_success 'setup reflog with alternating commits' '
	shit checkout -b topic &&
	shit reset one &&
	shit reset two &&
	shit reset one &&
	shit reset two
'

test_expect_success 'reflog shows all entries' '
	cat >expect <<-\EOF &&
		topic@{0} reset: moving to two
		topic@{1} reset: moving to one
		topic@{2} reset: moving to two
		topic@{3} reset: moving to one
		topic@{4} branch: Created from HEAD
	EOF
	shit log -g --format="%gd %gs" topic >actual &&
	test_cmp expect actual
'

test_done
