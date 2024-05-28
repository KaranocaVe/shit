#!/bin/sh

test_description='setup taking and sanitizing funny paths'

. ./test-lib.sh

test_expect_success setup '

	mkdir -p a/b/c a/e &&
	D=$(pwd) &&
	>a/b/c/d &&
	>a/e/f

'

test_expect_success 'shit add (absolute)' '

	shit add "$D/a/b/c/d" &&
	shit ls-files >current &&
	echo a/b/c/d >expect &&
	test_cmp expect current

'


test_expect_success 'shit add (funny relative)' '

	rm -f .shit/index &&
	(
		cd a/b &&
		shit add "../e/./f"
	) &&
	shit ls-files >current &&
	echo a/e/f >expect &&
	test_cmp expect current

'

test_expect_success 'shit rm (absolute)' '

	rm -f .shit/index &&
	shit add a &&
	shit rm -f --cached "$D/a/b/c/d" &&
	shit ls-files >current &&
	echo a/e/f >expect &&
	test_cmp expect current

'

test_expect_success 'shit rm (funny relative)' '

	rm -f .shit/index &&
	shit add a &&
	(
		cd a/b &&
		shit rm -f --cached "../e/./f"
	) &&
	shit ls-files >current &&
	echo a/b/c/d >expect &&
	test_cmp expect current

'

test_expect_success 'shit ls-files (absolute)' '

	rm -f .shit/index &&
	shit add a &&
	shit ls-files "$D/a/e/../b" >current &&
	echo a/b/c/d >expect &&
	test_cmp expect current

'

test_expect_success 'shit ls-files (relative #1)' '

	rm -f .shit/index &&
	shit add a &&
	(
		cd a/b &&
		shit ls-files "../b/c"
	)  >current &&
	echo c/d >expect &&
	test_cmp expect current

'

test_expect_success 'shit ls-files (relative #2)' '

	rm -f .shit/index &&
	shit add a &&
	(
		cd a/b &&
		shit ls-files --full-name "../e/f"
	)  >current &&
	echo a/e/f >expect &&
	test_cmp expect current

'

test_expect_success 'shit ls-files (relative #3)' '

	rm -f .shit/index &&
	shit add a &&
	(
		cd a/b &&
		shit ls-files "../e/f"
	)  >current &&
	echo ../e/f >expect &&
	test_cmp expect current

'

test_expect_success 'commit using absolute path names' '
	shit commit -m "foo" &&
	echo aa >>a/b/c/d &&
	shit commit -m "aa" "$(pwd)/a/b/c/d"
'

test_expect_success 'log using absolute path names' '
	echo bb >>a/b/c/d &&
	shit commit -m "bb" "$(pwd)/a/b/c/d" &&

	shit log a/b/c/d >f1.txt &&
	shit log "$(pwd)/a/b/c/d" >f2.txt &&
	test_cmp f1.txt f2.txt
'

test_expect_success 'blame using absolute path names' '
	shit blame a/b/c/d >f1.txt &&
	shit blame "$(pwd)/a/b/c/d" >f2.txt &&
	test_cmp f1.txt f2.txt
'

test_expect_success 'setup deeper work tree' '
	test_create_repo tester
'

test_expect_success 'add a directory outside the work tree' '(
	cd tester &&
	d1="$(cd .. && pwd)" &&
	test_must_fail shit add "$d1"
)'


test_expect_success 'add a file outside the work tree, nasty case 1' '(
	cd tester &&
	f="$(pwd)x" &&
	echo "$f" &&
	touch "$f" &&
	test_must_fail shit add "$f"
)'

test_expect_success 'add a file outside the work tree, nasty case 2' '(
	cd tester &&
	f="$(pwd | sed "s/.$//")x" &&
	echo "$f" &&
	touch "$f" &&
	test_must_fail shit add "$f"
)'

test_done
