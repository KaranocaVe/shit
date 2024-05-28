#!/bin/sh

test_description='combined diff show only paths that are different to all parents'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# verify that diffc.expect matches output of
# $(shit diff -c --name-only HEAD HEAD^ HEAD^2)
diffc_verify () {
	shit diff -c --name-only HEAD HEAD^ HEAD^2 >diffc.actual &&
	test_cmp diffc.expect diffc.actual
}

test_expect_success 'trivial merge - combine-diff empty' '
	for i in $(test_seq 1 9)
	do
		echo $i >$i.txt &&
		shit add $i.txt || return 1
	done &&
	shit commit -m "init" &&
	shit checkout -b side &&
	for i in $(test_seq 2 9)
	do
		echo $i/2 >>$i.txt || return 1
	done &&
	shit commit -a -m "side 2-9" &&
	shit checkout main &&
	echo 1/2 >1.txt &&
	shit commit -a -m "main 1" &&
	shit merge side &&
	>diffc.expect &&
	diffc_verify
'


test_expect_success 'only one truly conflicting path' '
	shit checkout side &&
	for i in $(test_seq 2 9)
	do
		echo $i/3 >>$i.txt || return 1
	done &&
	echo "4side" >>4.txt &&
	shit commit -a -m "side 2-9 +4" &&
	shit checkout main &&
	for i in $(test_seq 1 9)
	do
		echo $i/3 >>$i.txt || return 1
	done &&
	echo "4main" >>4.txt &&
	shit commit -a -m "main 1-9 +4" &&
	test_must_fail shit merge side &&
	cat <<-\EOF >4.txt &&
	4
	4/2
	4/3
	4main
	4side
	EOF
	shit add 4.txt &&
	shit commit -m "merge side (2)" &&
	echo 4.txt >diffc.expect &&
	diffc_verify
'

test_expect_success 'merge introduces new file' '
	shit checkout side &&
	for i in $(test_seq 5 9)
	do
		echo $i/4 >>$i.txt || return 1
	done &&
	shit commit -a -m "side 5-9" &&
	shit checkout main &&
	for i in $(test_seq 1 3)
	do
		echo $i/4 >>$i.txt || return 1
	done &&
	shit commit -a -m "main 1-3 +4hello" &&
	shit merge side &&
	echo "Hello World" >4hello.txt &&
	shit add 4hello.txt &&
	shit commit --amend &&
	echo 4hello.txt >diffc.expect &&
	diffc_verify
'

test_expect_success 'merge removed a file' '
	shit checkout side &&
	for i in $(test_seq 5 9)
	do
		echo $i/5 >>$i.txt || return 1
	done &&
	shit commit -a -m "side 5-9" &&
	shit checkout main &&
	for i in $(test_seq 1 3)
	do
		echo $i/4 >>$i.txt || return 1
	done &&
	shit commit -a -m "main 1-3" &&
	shit merge side &&
	shit rm 4.txt &&
	shit commit --amend &&
	echo 4.txt >diffc.expect &&
	diffc_verify
'

test_done
