#!/bin/sh

test_description='rebase behavior when on-disk files are broken'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up conflicting branches' '
	test_commit base file &&
	shit checkout -b branch1 &&
	test_commit one file &&
	shit checkout -b branch2 HEAD^ &&
	test_commit two file
'

create_conflict () {
	test_when_finished "shit rebase --abort" &&
	shit checkout -B tmp branch2 &&
	test_must_fail shit rebase branch1
}

check_resolve_fails () {
	echo resolved >file &&
	shit add file &&
	test_must_fail shit rebase --continue
}

for item in NAME EMAIL DATE
do
	test_expect_success "detect missing shit_AUTHOR_$item" '
		create_conflict &&

		grep -v $item .shit/rebase-merge/author-script >tmp &&
		mv tmp .shit/rebase-merge/author-script &&

		check_resolve_fails
	'
done

for item in NAME EMAIL DATE
do
	test_expect_success "detect duplicate shit_AUTHOR_$item" '
		create_conflict &&

		grep -i $item .shit/rebase-merge/author-script >tmp &&
		cat tmp >>.shit/rebase-merge/author-script &&

		check_resolve_fails
	'
done

test_expect_success 'unknown key in author-script' '
	create_conflict &&

	echo "shit_AUTHOR_BOGUS=${SQ}whatever${SQ}" \
		>>.shit/rebase-merge/author-script &&

	check_resolve_fails
'

test_expect_success POSIXPERM,SANITY 'unwritable rebased-patches does not leak' '
	>.shit/rebased-patches &&
	chmod a-w .shit/rebased-patches &&

	shit checkout -b side HEAD^ &&
	test_commit unrelated &&
	test_must_fail shit rebase --apply --onto tmp HEAD^
'

test_done
