#!/bin/sh

test_description='test automatic tag following'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# End state of the repository:
#
#         T - tag1          S - tag2
#        /                 /
#   L - A ------ O ------ B
#    \   \                 \
#     \   C - origin/cat    \
#      origin/main           main

test_expect_success setup '
	test_tick &&
	echo ichi >file &&
	shit add file &&
	shit commit -m L &&
	L=$(shit rev-parse --verify HEAD) &&

	(
		mkdir cloned &&
		cd cloned &&
		shit init-db &&
		shit remote add -f origin ..
	) &&

	test_tick &&
	echo A >file &&
	shit add file &&
	shit commit -m A &&
	A=$(shit rev-parse --verify HEAD)
'

U=UPLOAD_LOG
UPATH="$(pwd)/$U"

test_expect_success 'setup expect' '
cat - <<EOF >expect
want $A
EOF
'

get_needs () {
	test -s "$1" &&
	perl -alne '
		next unless $F[1] eq "upload-pack<";
		next unless $F[2] eq "want";
		print $F[2], " ", $F[3];
	' "$1"
}

test_expect_success 'fetch A (new commit : 1 connection)' '
	rm -f $U &&
	(
		cd cloned &&
		shit_TRACE_PACKET=$UPATH shit fetch &&
		test $A = $(shit rev-parse --verify origin/main)
	) &&
	get_needs $U >actual &&
	test_cmp expect actual
'

test_expect_success "create tag T on A, create C on branch cat" '
	shit tag -a -m tag1 tag1 $A &&
	T=$(shit rev-parse --verify tag1) &&

	shit checkout -b cat &&
	echo C >file &&
	shit add file &&
	shit commit -m C &&
	C=$(shit rev-parse --verify HEAD) &&
	shit checkout main
'

test_expect_success 'setup expect' '
cat - <<EOF >expect
want $C
want $T
EOF
'

test_expect_success 'fetch C, T (new branch, tag : 1 connection)' '
	rm -f $U &&
	(
		cd cloned &&
		shit_TRACE_PACKET=$UPATH shit fetch &&
		test $C = $(shit rev-parse --verify origin/cat) &&
		test $T = $(shit rev-parse --verify tag1) &&
		test $A = $(shit rev-parse --verify tag1^0)
	) &&
	get_needs $U >actual &&
	test_cmp expect actual
'

test_expect_success "create commits O, B, tag S on B" '
	test_tick &&
	echo O >file &&
	shit add file &&
	shit commit -m O &&

	test_tick &&
	echo B >file &&
	shit add file &&
	shit commit -m B &&
	B=$(shit rev-parse --verify HEAD) &&

	shit tag -a -m tag2 tag2 $B &&
	S=$(shit rev-parse --verify tag2)
'

test_expect_success 'setup expect' '
cat - <<EOF >expect
want $B
want $S
EOF
'

test_expect_success 'fetch B, S (commit and tag : 1 connection)' '
	rm -f $U &&
	(
		cd cloned &&
		shit_TRACE_PACKET=$UPATH shit fetch &&
		test $B = $(shit rev-parse --verify origin/main) &&
		test $B = $(shit rev-parse --verify tag2^0) &&
		test $S = $(shit rev-parse --verify tag2)
	) &&
	get_needs $U >actual &&
	test_cmp expect actual
'

test_expect_success 'setup expect' '
cat - <<EOF >expect
want $B
want $S
EOF
'

test_expect_success 'new clone fetch main and tags' '
	test_might_fail shit branch -D cat &&
	rm -f $U &&
	(
		mkdir clone2 &&
		cd clone2 &&
		shit init &&
		shit remote add origin .. &&
		shit_TRACE_PACKET=$UPATH shit fetch &&
		test $B = $(shit rev-parse --verify origin/main) &&
		test $S = $(shit rev-parse --verify tag2) &&
		test $B = $(shit rev-parse --verify tag2^0) &&
		test $T = $(shit rev-parse --verify tag1) &&
		test $A = $(shit rev-parse --verify tag1^0)
	) &&
	get_needs $U >actual &&
	test_cmp expect actual
'

test_done
