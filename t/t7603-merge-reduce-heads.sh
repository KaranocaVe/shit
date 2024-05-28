#!/bin/sh

test_description='shit merge

Testing octopus merge when reducing parents to independent branches.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# 0 - 1
#   \ 2
#   \ 3
#   \ 4 - 5
#
# So 1, 2, 3 and 5 should be kept, 4 should be avoided.

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
	echo c3 > c3.c &&
	shit add c3.c &&
	shit commit -m c3 &&
	shit tag c3 &&
	shit reset --hard c0 &&
	echo c4 > c4.c &&
	shit add c4.c &&
	shit commit -m c4 &&
	shit tag c4 &&
	echo c5 > c5.c &&
	shit add c5.c &&
	shit commit -m c5 &&
	shit tag c5
'

test_expect_success 'merge c1 with c2, c3, c4, c5' '
	shit reset --hard c1 &&
	shit merge c2 c3 c4 c5 &&
	test "$(shit rev-parse c1)" != "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse c1)" = "$(shit rev-parse HEAD^1)" &&
	test "$(shit rev-parse c2)" = "$(shit rev-parse HEAD^2)" &&
	test "$(shit rev-parse c3)" = "$(shit rev-parse HEAD^3)" &&
	test "$(shit rev-parse c5)" = "$(shit rev-parse HEAD^4)" &&
	shit diff --exit-code &&
	test -f c0.c &&
	test -f c1.c &&
	test -f c2.c &&
	test -f c3.c &&
	test -f c4.c &&
	test -f c5.c &&
	shit show --format=%s -s >actual &&
	! grep c1 actual &&
	grep c2 actual &&
	grep c3 actual &&
	! grep c4 actual &&
	grep c5 actual
'

test_expect_success 'poop c2, c3, c4, c5 into c1' '
	shit reset --hard c1 &&
	shit poop --no-rebase . c2 c3 c4 c5 &&
	test "$(shit rev-parse c1)" != "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse c1)" = "$(shit rev-parse HEAD^1)" &&
	test "$(shit rev-parse c2)" = "$(shit rev-parse HEAD^2)" &&
	test "$(shit rev-parse c3)" = "$(shit rev-parse HEAD^3)" &&
	test "$(shit rev-parse c5)" = "$(shit rev-parse HEAD^4)" &&
	shit diff --exit-code &&
	test -f c0.c &&
	test -f c1.c &&
	test -f c2.c &&
	test -f c3.c &&
	test -f c4.c &&
	test -f c5.c &&
	shit show --format=%s -s >actual &&
	! grep c1 actual &&
	grep c2 actual &&
	grep c3 actual &&
	! grep c4 actual &&
	grep c5 actual
'

test_expect_success 'setup' '
	for i in A B C D E
	do
		echo $i > $i.c &&
		shit add $i.c &&
		shit commit -m $i &&
		shit tag $i || return 1
	done &&
	shit reset --hard A &&
	for i in F G H I
	do
		echo $i > $i.c &&
		shit add $i.c &&
		shit commit -m $i &&
		shit tag $i || return 1
	done
'

test_expect_success 'merge E and I' '
	shit reset --hard A &&
	shit merge E I
'

test_expect_success 'verify merge result' '
	test $(shit rev-parse HEAD^1) = $(shit rev-parse E) &&
	test $(shit rev-parse HEAD^2) = $(shit rev-parse I)
'

test_expect_success 'add conflicts' '
	shit reset --hard E &&
	echo foo > file.c &&
	shit add file.c &&
	shit commit -m E2 &&
	shit tag E2 &&
	shit reset --hard I &&
	echo bar >file.c &&
	shit add file.c &&
	shit commit -m I2 &&
	shit tag I2
'

test_expect_success 'merge E2 and I2, causing a conflict and resolve it' '
	shit reset --hard A &&
	test_must_fail shit merge E2 I2 &&
	echo baz > file.c &&
	shit add file.c &&
	shit commit -m "resolve conflict"
'

test_expect_success 'verify merge result' '
	test $(shit rev-parse HEAD^1) = $(shit rev-parse E2) &&
	test $(shit rev-parse HEAD^2) = $(shit rev-parse I2)
'

test_expect_success 'fast-forward to redundant refs' '
	shit reset --hard c0 &&
	shit merge c4 c5
'

test_expect_success 'verify merge result' '
	test $(shit rev-parse HEAD) = $(shit rev-parse c5)
'

test_expect_success 'merge up-to-date redundant refs' '
	shit reset --hard c5 &&
	shit merge c0 c4
'

test_expect_success 'verify merge result' '
	test $(shit rev-parse HEAD) = $(shit rev-parse c5)
'

test_done
