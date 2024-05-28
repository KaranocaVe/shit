#!/bin/sh

test_description='merge fast-forward and up to date'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit tag c0 &&

	echo second >file &&
	shit add file &&
	test_tick &&
	shit commit -m second &&
	shit tag c1 &&
	shit branch test &&
	echo third >file &&
	shit add file &&
	test_tick &&
	shit commit -m third &&
	shit tag c2
'

test_expect_success 'merge -s recursive up-to-date' '

	shit reset --hard c1 &&
	test_tick &&
	shit merge -s recursive c0 &&
	expect=$(shit rev-parse c1) &&
	current=$(shit rev-parse HEAD) &&
	test "$expect" = "$current"

'

test_expect_success 'merge -s recursive fast-forward' '

	shit reset --hard c0 &&
	test_tick &&
	shit merge -s recursive c1 &&
	expect=$(shit rev-parse c1) &&
	current=$(shit rev-parse HEAD) &&
	test "$expect" = "$current"

'

test_expect_success 'merge -s ours up-to-date' '

	shit reset --hard c1 &&
	test_tick &&
	shit merge -s ours c0 &&
	expect=$(shit rev-parse c1) &&
	current=$(shit rev-parse HEAD) &&
	test "$expect" = "$current"

'

test_expect_success 'merge -s ours fast-forward' '

	shit reset --hard c0 &&
	test_tick &&
	shit merge -s ours c1 &&
	expect=$(shit rev-parse c0^{tree}) &&
	current=$(shit rev-parse HEAD^{tree}) &&
	test "$expect" = "$current"

'

test_expect_success 'merge -s subtree up-to-date' '

	shit reset --hard c1 &&
	test_tick &&
	shit merge -s subtree c0 &&
	expect=$(shit rev-parse c1) &&
	current=$(shit rev-parse HEAD) &&
	test "$expect" = "$current"

'

test_expect_success 'merge fast-forward octopus' '

	shit reset --hard c0 &&
	test_tick &&
	shit merge c1 c2 &&
	expect=$(shit rev-parse c2) &&
	current=$(shit rev-parse HEAD) &&
	test "$expect" = "$current"
'

test_done
