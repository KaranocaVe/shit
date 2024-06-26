#!/bin/sh
#
# Copyright (c) 2012 Mozilla Foundation
#

test_description='diff.context configuration'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cat >template <<-\EOF &&
	firstline
	b
	c
	d
	e
	f
	preline
	TARGET
	postline
	i
	j
	k
	l
	m
	n
	EOF
	sed "/TARGET/d" >x <template &&
	shit update-index --add x &&
	shit commit -m initial &&

	sed "s/TARGET/ADDED/" >x <template &&
	shit update-index --add x &&
	shit commit -m next &&

	sed "s/TARGET/MODIFIED/" >x <template
'

test_expect_success 'the default number of context lines is 3' '
	shit diff >output &&
	! grep "^ d" output &&
	grep "^ e" output &&
	grep "^ j" output &&
	! grep "^ k" output
'

test_expect_success 'diff.context honored by "log"' '
	shit log -1 -p >output &&
	! grep firstline output &&
	shit config diff.context 8 &&
	shit log -1 -p >output &&
	grep "^ firstline" output
'

test_expect_success 'The -U option overrides diff.context' '
	shit config diff.context 8 &&
	shit log -U4 -1 >output &&
	! grep "^ firstline" output
'

test_expect_success 'diff.context honored by "diff"' '
	shit config diff.context 8 &&
	shit diff >output &&
	grep "^ firstline" output
'

test_expect_success 'plumbing not affected' '
	shit config diff.context 8 &&
	shit diff-files -p >output &&
	! grep "^ firstline" output
'

test_expect_success 'non-integer config parsing' '
	shit config diff.context no &&
	test_must_fail shit diff 2>output &&
	test_grep "bad numeric config value" output
'

test_expect_success 'negative integer config parsing' '
	shit config diff.context -1 &&
	test_must_fail shit diff 2>output &&
	test_grep "bad config variable" output
'

test_expect_success '-U0 is valid, so is diff.context=0' '
	shit config diff.context 0 &&
	shit diff >output &&
	grep "^-ADDED" output &&
	grep "^+MODIFIED" output
'

test_done
