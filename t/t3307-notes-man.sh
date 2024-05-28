#!/bin/sh

test_description='Examples from the shit-notes man page

Make sure the manual is not full of lies.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit A &&
	test_commit B &&
	test_commit C
'

test_expect_success 'example 1: notes to add an Acked-by line' '
	cat <<-\EOF >expect &&
	    B

	Notes:
	    Acked-by: A C Ker <acker@example.com>
	EOF
	shit notes add -m "Acked-by: A C Ker <acker@example.com>" B &&
	shit show -s B^{commit} >log &&
	tail -n 4 log >actual &&
	test_cmp expect actual
'

test_expect_success 'example 2: binary notes' '
	cp "$TEST_DIRECTORY"/test-binary-1.png . &&
	shit checkout B &&
	blob=$(shit hash-object -w test-binary-1.png) &&
	shit notes --ref=logo add -C "$blob" &&
	shit notes --ref=logo copy B C &&
	shit notes --ref=logo show C >actual &&
	test_cmp test-binary-1.png actual
'

test_done
