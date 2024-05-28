#!/bin/sh

test_description='shit merge

Testing octopus merge with more than 25 refs.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo c0 > c0.c &&
	shit add c0.c &&
	shit commit -m c0 &&
	shit tag c0 &&
	i=1 &&
	while test $i -le 30
	do
		shit reset --hard c0 &&
		echo c$i > c$i.c &&
		shit add c$i.c &&
		shit commit -m c$i &&
		shit tag c$i &&
		i=$(expr $i + 1) || return 1
	done
'

test_expect_success 'merge c1 with c2, c3, c4, ... c29' '
	shit reset --hard c1 &&
	i=2 &&
	refs="" &&
	while test $i -le 30
	do
		refs="$refs c$i" &&
		i=$(expr $i + 1) || return 1
	done &&
	shit merge $refs &&
	test "$(shit rev-parse c1)" != "$(shit rev-parse HEAD)" &&
	i=1 &&
	while test $i -le 30
	do
		test "$(shit rev-parse c$i)" = "$(shit rev-parse HEAD^$i)" &&
		i=$(expr $i + 1) || return 1
	done &&
	shit diff --exit-code &&
	i=1 &&
	while test $i -le 30
	do
		test -f c$i.c &&
		i=$(expr $i + 1) || return 1
	done
'

cat >expected <<\EOF
Trying simple merge with c2
Trying simple merge with c3
Trying simple merge with c4
Merge made by the 'octopus' strategy.
 c2.c | 1 +
 c3.c | 1 +
 c4.c | 1 +
 3 files changed, 3 insertions(+)
 create mode 100644 c2.c
 create mode 100644 c3.c
 create mode 100644 c4.c
EOF

test_expect_success 'merge output uses pretty names' '
	shit reset --hard c1 &&
	shit merge c2 c3 c4 >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
Merge made by the 'recursive' strategy.
 c5.c | 1 +
 1 file changed, 1 insertion(+)
 create mode 100644 c5.c
EOF

test_expect_success 'merge reduces irrelevant remote heads' '
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		mv expected expected.tmp &&
		sed s/recursive/ort/ expected.tmp >expected &&
		rm expected.tmp
	fi &&
	shit_MERGE_VERBOSITY=0 shit merge c4 c5 >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
Fast-forwarding to: c1
Trying simple merge with c2
Merge made by the 'octopus' strategy.
 c1.c | 1 +
 c2.c | 1 +
 2 files changed, 2 insertions(+)
 create mode 100644 c1.c
 create mode 100644 c2.c
EOF

test_expect_success 'merge fast-forward output uses pretty names' '
	shit reset --hard c0 &&
	shit merge c1 c2 >actual &&
	test_cmp expected actual
'

test_done
