#!/bin/sh

test_description='test cherry-picking many commits'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_head_differs_from() {
	test_cmp_rev ! HEAD "$1"
}

check_head_equals() {
	test_cmp_rev HEAD "$1"
}

test_expect_success setup '
	echo first > file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m "first" &&
	shit tag first &&

	shit checkout -b other &&
	for val in second third fourth
	do
		echo $val >> file1 &&
		shit add file1 &&
		test_tick &&
		shit commit -m "$val" &&
		shit tag $val || return 1
	done
'

test_expect_success 'cherry-pick first..fourth works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick first..fourth &&
	shit diff --quiet other &&
	shit diff --quiet HEAD other &&
	check_head_differs_from fourth
'

test_expect_success 'cherry-pick three one two works' '
	shit checkout -f first &&
	test_commit one &&
	test_commit two &&
	test_commit three &&
	shit checkout -f main &&
	shit reset --hard first &&
	shit cherry-pick three one two &&
	shit diff --quiet three &&
	shit diff --quiet HEAD three &&
	test "$(shit log --reverse --format=%s first..)" = "three
one
two"
'

test_expect_success 'cherry-pick three one two: fails' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_must_fail shit cherry-pick three one two:
'

test_expect_success 'output to keep user entertained during multi-pick' '
	cat <<-\EOF >expected &&
	[main OBJID] second
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:14:13 2005 -0700
	 1 file changed, 1 insertion(+)
	[main OBJID] third
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:15:13 2005 -0700
	 1 file changed, 1 insertion(+)
	[main OBJID] fourth
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:16:13 2005 -0700
	 1 file changed, 1 insertion(+)
	EOF

	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick first..fourth >actual &&
	sed -e "s/$_x05[0-9a-f][0-9a-f]/OBJID/" <actual >actual.fuzzy &&
	test_line_count -ge 3 actual.fuzzy &&
	test_cmp expected actual.fuzzy
'

test_expect_success 'cherry-pick --strategy resolve first..fourth works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick --strategy resolve first..fourth &&
	shit diff --quiet other &&
	shit diff --quiet HEAD other &&
	check_head_differs_from fourth
'

test_expect_success 'output during multi-pick indicates merge strategy' '
	cat <<-\EOF >expected &&
	Trying simple merge.
	[main OBJID] second
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:14:13 2005 -0700
	 1 file changed, 1 insertion(+)
	Trying simple merge.
	[main OBJID] third
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:15:13 2005 -0700
	 1 file changed, 1 insertion(+)
	Trying simple merge.
	[main OBJID] fourth
	 Author: A U Thor <author@example.com>
	 Date: Thu Apr 7 15:16:13 2005 -0700
	 1 file changed, 1 insertion(+)
	EOF

	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick --strategy resolve first..fourth >actual &&
	sed -e "s/$_x05[0-9a-f][0-9a-f]/OBJID/" <actual >actual.fuzzy &&
	test_cmp expected actual.fuzzy
'

test_expect_success 'cherry-pick --ff first..fourth works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick --ff first..fourth &&
	shit diff --quiet other &&
	shit diff --quiet HEAD other &&
	check_head_equals fourth
'

test_expect_success 'cherry-pick -n first..fourth works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick -n first..fourth &&
	shit diff --quiet other &&
	shit diff --cached --quiet other &&
	shit diff --quiet HEAD first
'

test_expect_success 'revert first..fourth works' '
	shit checkout -f main &&
	shit reset --hard fourth &&
	test_tick &&
	shit revert first..fourth &&
	shit diff --quiet first &&
	shit diff --cached --quiet first &&
	shit diff --quiet HEAD first
'

test_expect_success 'revert ^first fourth works' '
	shit checkout -f main &&
	shit reset --hard fourth &&
	test_tick &&
	shit revert ^first fourth &&
	shit diff --quiet first &&
	shit diff --cached --quiet first &&
	shit diff --quiet HEAD first
'

test_expect_success 'revert fourth fourth~1 fourth~2 works' '
	shit checkout -f main &&
	shit reset --hard fourth &&
	test_tick &&
	shit revert fourth fourth~1 fourth~2 &&
	shit diff --quiet first &&
	shit diff --cached --quiet first &&
	shit diff --quiet HEAD first
'

test_expect_success 'cherry-pick -3 fourth works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit cherry-pick -3 fourth &&
	shit diff --quiet other &&
	shit diff --quiet HEAD other &&
	check_head_differs_from fourth
'

test_expect_success 'cherry-pick --stdin works' '
	shit checkout -f main &&
	shit reset --hard first &&
	test_tick &&
	shit rev-list --reverse first..fourth | shit cherry-pick --stdin &&
	shit diff --quiet other &&
	shit diff --quiet HEAD other &&
	check_head_differs_from fourth
'

test_done
