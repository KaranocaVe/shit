#!/bin/sh

test_description='merging with large rename matrix'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

count() {
	i=1
	while test $i -le $1; do
		echo $i
		i=$(($i + 1))
	done
}

test_expect_success 'setup (initial)' '
	touch file &&
	shit add . &&
	shit commit -m initial &&
	shit tag initial
'

make_text() {
	echo $1: $2
	for i in $(count 20); do
		echo $1: $i
	done
	echo $1: $3
}

test_rename() {
	test_expect_success "rename ($1, $2)" '
	n='$1' &&
	expect='$2' &&
	shit checkout -f main &&
	test_might_fail shit branch -D test$n &&
	shit reset --hard initial &&
	for i in $(count $n); do
		make_text $i initial initial >$i || return 1
	done &&
	shit add . &&
	shit commit -m add=$n &&
	for i in $(count $n); do
		make_text $i changed initial >$i || return 1
	done &&
	shit commit -a -m change=$n &&
	shit checkout -b test$n HEAD^ &&
	for i in $(count $n); do
		shit rm $i &&
		make_text $i initial changed >$i.moved || return 1
	done &&
	shit add . &&
	shit commit -m change+rename=$n &&
	case "$expect" in
		ok) shit merge main ;;
		 *) test_must_fail shit merge main ;;
	esac
	'
}

test_rename 5 ok

test_expect_success 'set diff.renamelimit to 4' '
	shit config diff.renamelimit 4
'
test_rename 4 ok
test_rename 5 fail

test_expect_success 'set merge.renamelimit to 5' '
	shit config merge.renamelimit 5
'
test_rename 5 ok
test_rename 6 fail

test_expect_success 'setup large simple rename' '
	shit config --unset merge.renamelimit &&
	shit config --unset diff.renamelimit &&

	shit reset --hard initial &&
	for i in $(count 200); do
		make_text foo bar baz >$i || return 1
	done &&
	shit add . &&
	shit commit -m create-files &&

	shit branch simple-change &&
	shit checkout -b simple-rename &&

	mkdir builtin &&
	shit mv [0-9]* builtin/ &&
	shit commit -m renamed &&

	shit checkout simple-change &&
	>unrelated-change &&
	shit add unrelated-change &&
	shit commit -m unrelated-change
'

test_expect_success 'massive simple rename does not spam added files' '
	sane_unset shit_MERGE_VERBOSITY &&
	shit merge --no-stat simple-rename | grep -v Removing >output &&
	test_line_count -lt 5 output
'

test_done
