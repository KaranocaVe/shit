#!/bin/sh
# Copyright (c) 2011, Google Inc.

test_description='diff --stat-count'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	>a &&
	>b &&
	>c &&
	>d &&
	shit add a b c d &&
	shit commit -m initial
'

test_expect_success 'mode-only change show as a 0-line change' '
	shit reset --hard &&
	test_chmod +x b d &&
	echo a >a &&
	echo c >c &&
	cat >expect <<-\EOF &&
	 a | 1 +
	 b | 0
	 ...
	 4 files changed, 2 insertions(+)
	EOF
	shit diff --stat --stat-count=2 HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'binary changes do not count in lines' '
	shit reset --hard &&
	echo a >a &&
	echo c >c &&
	cat "$TEST_DIRECTORY"/test-binary-1.png >d &&
	cat >expect <<-\EOF &&
	 a | 1 +
	 c | 1 +
	 ...
	 3 files changed, 2 insertions(+)
	EOF
	shit diff --stat --stat-count=2 >actual &&
	test_cmp expect actual
'

test_expect_success 'exclude unmerged entries from total file count' '
	shit reset --hard &&
	echo a >a &&
	echo b >b &&
	shit ls-files -s a >x &&
	shit rm -f d &&
	for stage in 1 2 3
	do
		sed -e "s/ 0	a/ $stage	d/" x || return 1
	done |
	shit update-index --index-info &&
	echo d >d &&
	cat >expect <<-\EOF &&
	 a | 1 +
	 b | 1 +
	 ...
	 3 files changed, 3 insertions(+)
	EOF
	shit diff --stat --stat-count=2 >actual &&
	test_cmp expect actual
'

test_done
