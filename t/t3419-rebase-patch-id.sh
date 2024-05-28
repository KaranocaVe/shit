#!/bin/sh

test_description='shit rebase - test patch id computation'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

scramble () {
	i=0
	while read x
	do
		if test $i -ne 0
		then
			echo "$x"
		fi
		i=$((($i+1) % 10))
	done <"$1" >"$1.new"
	mv -f "$1.new" "$1"
}

test_expect_success 'setup' '
	shit commit --allow-empty -m initial &&
	shit tag root
'

test_expect_success 'setup: 500 lines' '
	rm -f .shitattributes &&
	shit checkout -q -f main &&
	shit reset --hard root &&
	test_seq 500 >file &&
	shit add file &&
	shit commit -q -m initial &&
	shit branch -f other &&

	scramble file &&
	shit add file &&
	shit commit -q -m "change big file" &&

	shit checkout -q other &&
	: >newfile &&
	shit add newfile &&
	shit commit -q -m "add small file" &&

	shit cherry-pick main >/dev/null 2>&1 &&

	shit branch -f squashed main &&
	shit checkout -q -f squashed &&
	shit reset -q --soft HEAD~2 &&
	shit commit -q -m squashed &&

	shit branch -f mode main &&
	shit checkout -q -f mode &&
	test_chmod +x file &&
	shit commit -q -a --amend &&

	shit branch -f modeother other &&
	shit checkout -q -f modeother &&
	test_chmod +x file &&
	shit commit -q -a --amend
'

test_expect_success 'detect upstream patch' '
	shit checkout -q main^{} &&
	scramble file &&
	shit add file &&
	shit commit -q -m "change big file again" &&
	shit checkout -q other^{} &&
	shit rebase main &&
	shit rev-list main...HEAD~ >revs &&
	test_must_be_empty revs
'

test_expect_success 'detect upstream patch binary' '
	echo "file binary" >.shitattributes &&
	shit checkout -q other^{} &&
	shit rebase main &&
	shit rev-list main...HEAD~ >revs &&
	test_must_be_empty revs &&
	test_when_finished "rm .shitattributes"
'

test_expect_success 'detect upstream patch modechange' '
	shit checkout -q modeother^{} &&
	shit rebase mode &&
	shit rev-list mode...HEAD~ >revs &&
	test_must_be_empty revs
'

test_expect_success 'do not drop patch' '
	shit checkout -q other^{} &&
	test_must_fail shit rebase squashed &&
	test_when_finished "shit rebase --abort"
'

test_expect_success 'do not drop patch binary' '
	echo "file binary" >.shitattributes &&
	shit checkout -q other^{} &&
	test_must_fail shit rebase squashed &&
	test_when_finished "shit rebase --abort" &&
	test_when_finished "rm .shitattributes"
'

test_expect_success 'do not drop patch modechange' '
	shit checkout -q modeother^{} &&
	shit rebase other &&
	cat >expected <<-\EOF &&
	diff --shit a/file b/file
	old mode 100644
	new mode 100755
	EOF
	shit diff HEAD~ >modediff &&
	test_cmp expected modediff
'

test_done
