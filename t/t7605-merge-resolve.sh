#!/bin/sh

test_description='shit merge

Testing the resolve strategy.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo c0 > c0.c &&
	shit add c0.c &&
	shit commit -m c0 &&
	shit tag c0 &&
	echo c1 > c1.c &&
	shit add c1.c &&
	shit commit -m c1 &&
	shit tag c1 &&
	shit reset --hard c0 &&
	echo c2 > c2.c &&
	shit add c2.c &&
	shit commit -m c2 &&
	shit tag c2 &&
	shit reset --hard c0 &&
	echo c3 > c2.c &&
	shit add c2.c &&
	shit commit -m c3 &&
	shit tag c3
'

merge_c1_to_c2_cmds='
	shit reset --hard c1 &&
	shit merge -s resolve c2 &&
	test "$(shit rev-parse c1)" != "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse c1)" = "$(shit rev-parse HEAD^1)" &&
	test "$(shit rev-parse c2)" = "$(shit rev-parse HEAD^2)" &&
	shit diff --exit-code &&
	test -f c0.c &&
	test -f c1.c &&
	test -f c2.c &&
	test 3 = $(shit ls-tree -r HEAD | wc -l) &&
	test 3 = $(shit ls-files | wc -l)
'

test_expect_success 'merge c1 to c2'        "$merge_c1_to_c2_cmds"

test_expect_success 'merge c1 to c2, again' "$merge_c1_to_c2_cmds"

test_expect_success 'merge c2 to c3 (fails)' '
	shit reset --hard c2 &&
	test_must_fail shit merge -s resolve c3
'
test_done
