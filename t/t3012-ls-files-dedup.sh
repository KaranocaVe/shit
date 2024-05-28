#!/bin/sh

test_description='shit ls-files --deduplicate test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	>a.txt &&
	>b.txt &&
	>delete.txt &&
	shit add a.txt b.txt delete.txt &&
	shit commit -m base &&
	echo a >a.txt &&
	echo b >b.txt &&
	echo delete >delete.txt &&
	shit add a.txt b.txt delete.txt &&
	shit commit -m tip &&
	shit tag tip &&
	shit reset --hard HEAD^ &&
	echo change >a.txt &&
	shit commit -a -m side &&
	shit tag side
'

test_expect_success 'shit ls-files --deduplicate to show unique unmerged path' '
	test_must_fail shit merge tip &&
	shit ls-files --deduplicate >actual &&
	cat >expect <<-\EOF &&
	a.txt
	b.txt
	delete.txt
	EOF
	test_cmp expect actual &&
	shit merge --abort
'

test_expect_success 'shit ls-files -d -m --deduplicate with different display options' '
	shit reset --hard side &&
	test_must_fail shit merge tip &&
	rm delete.txt &&
	shit ls-files -d -m --deduplicate >actual &&
	cat >expect <<-\EOF &&
	a.txt
	delete.txt
	EOF
	test_cmp expect actual &&
	shit ls-files -d -m -t --deduplicate >actual &&
	cat >expect <<-\EOF &&
	C a.txt
	C a.txt
	C a.txt
	R delete.txt
	C delete.txt
	EOF
	test_cmp expect actual &&
	shit ls-files -d -m -c --deduplicate >actual &&
	cat >expect <<-\EOF &&
	a.txt
	b.txt
	delete.txt
	EOF
	test_cmp expect actual &&
	shit merge --abort
'

test_done
