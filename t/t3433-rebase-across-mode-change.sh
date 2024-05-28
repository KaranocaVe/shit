#!/bin/sh

test_description='shit rebase across mode change'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir DS &&
	>DS/whatever &&
	shit add DS &&
	shit commit -m base &&

	shit branch side1 &&
	shit branch side2 &&

	shit checkout side1 &&
	shit rm -rf DS &&
	test_ln_s_add unrelated DS &&
	shit commit -m side1 &&

	shit checkout side2 &&
	>unrelated &&
	shit add unrelated &&
	shit commit -m commit1 &&

	echo >>unrelated &&
	shit commit -am commit2
'

test_expect_success 'rebase changes with the apply backend' '
	test_when_finished "shit rebase --abort || true" &&
	shit checkout -b apply-backend side2 &&
	shit rebase side1
'

test_expect_success 'rebase changes with the merge backend' '
	test_when_finished "shit rebase --abort || true" &&
	shit checkout -b merge-backend side2 &&
	shit rebase -m side1
'

test_expect_success 'rebase changes with the merge backend with a delay' '
	test_when_finished "shit rebase --abort || true" &&
	shit checkout -b merge-delay-backend side2 &&
	shit rebase -m --exec "sleep 1" side1
'

test_done
