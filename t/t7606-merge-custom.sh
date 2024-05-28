#!/bin/sh

test_description="shit merge

Testing a custom strategy.

*   (HEAD, main) Merge commit 'c3'
|\
| * (tag: c3) c3
* | (tag: c1) c1
|/
| * tag: c2) c2
|/
* (tag: c0) c0
"

. ./test-lib.sh

test_expect_success 'set up custom strategy' '
	cat >shit-merge-theirs <<-EOF &&
	#!$SHELL_PATH
	eval shit read-tree --reset -u \\\$\$#
	EOF

	chmod +x shit-merge-theirs &&
	PATH=.:$PATH &&
	export PATH
'

test_expect_success 'setup' '
	test_commit c0 c0.c &&
	test_commit c1 c1.c &&
	shit reset --keep c0 &&
	echo c1c1 >c1.c &&
	shit add c1.c &&
	test_commit c2 c2.c &&
	shit reset --keep c0 &&
	test_commit c3 c3.c
'

test_expect_success 'merge c2 with a custom strategy' '
	shit reset --hard c1 &&

	shit rev-parse c1 >head.old &&
	shit rev-parse c2 >second-parent.expected &&
	shit rev-parse c2^{tree} >tree.expected &&
	shit merge -s theirs c2 &&

	shit rev-parse HEAD >head.new &&
	shit rev-parse HEAD^1 >first-parent &&
	shit rev-parse HEAD^2 >second-parent &&
	shit rev-parse HEAD^{tree} >tree &&
	shit update-index --refresh &&
	shit diff --exit-code &&
	shit diff --exit-code c2 HEAD &&
	shit diff --exit-code c2 &&

	! test_cmp head.old head.new &&
	test_cmp head.old first-parent &&
	test_cmp second-parent.expected second-parent &&
	test_cmp tree.expected tree &&
	test -f c0.c &&
	grep c1c1 c1.c &&
	test -f c2.c
'

test_expect_success 'trivial merge with custom strategy' '
	shit reset --hard c1 &&

	shit rev-parse c1 >head.old &&
	shit rev-parse c3 >second-parent.expected &&
	shit rev-parse c3^{tree} >tree.expected &&
	shit merge -s theirs c3 &&

	shit rev-parse HEAD >head.new &&
	shit rev-parse HEAD^1 >first-parent &&
	shit rev-parse HEAD^2 >second-parent &&
	shit rev-parse HEAD^{tree} >tree &&
	shit update-index --refresh &&
	shit diff --exit-code &&
	shit diff --exit-code c3 HEAD &&
	shit diff --exit-code c3 &&

	! test_cmp head.old head.new &&
	test_cmp head.old first-parent &&
	test_cmp second-parent.expected second-parent &&
	test_cmp tree.expected tree &&
	test -f c0.c &&
	! test -e c1.c &&
	test -f c3.c
'

test_done
