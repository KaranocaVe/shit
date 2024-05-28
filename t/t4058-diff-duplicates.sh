#!/bin/sh

# NOTICE:
#   This testsuite does a number of diffs and checks that the output match.
#   However, it is a "garbage in, garbage out" situation; the trees have
#   duplicate entries for individual paths, and it results in diffs that do
#   not make much sense.  As such, it is not clear that the diffs are
#   "correct".  The primary purpose of these tests was to verify that
#   diff-tree does not segfault, but there is perhaps some value in ensuring
#   that the diff output isn't wildly unreasonable.

test_description='test tree diff when trees have duplicate entries'
. ./test-lib.sh

# make_tree_entry <mode> <mode> <sha1>
#
# We have to rely on perl here because not all printfs understand
# hex escapes (only octal), and xxd is not portable.
make_tree_entry () {
	printf '%s %s\0' "$1" "$2" &&
	perl -e 'print chr(hex($_)) for ($ARGV[0] =~ /../g)' "$3"
}

# Like shit-mktree, but without all of the pesky sanity checking.
# Arguments come in groups of three, each group specifying a single
# tree entry (see make_tree_entry above).
make_tree () {
	while test $# -gt 2; do
		make_tree_entry "$1" "$2" "$3"
		shift; shift; shift
	done |
	shit hash-object --literally -w -t tree --stdin
}

# this is kind of a convoluted setup, but matches
# a real-world case. Each tree contains four entries
# for the given path, one with one sha1, and three with
# the other. The first tree has them split across
# two subtrees (which are themselves duplicate entries in
# the root tree), and the second has them all in a single subtree.
test_expect_success 'create trees with duplicate entries' '
	blob_one=$(echo one | shit hash-object -w --stdin) &&
	blob_two=$(echo two | shit hash-object -w --stdin) &&
	inner_one_a=$(make_tree \
		100644 inner $blob_one
	) &&
	inner_one_b=$(make_tree \
		100644 inner $blob_two \
		100644 inner $blob_two \
		100644 inner $blob_two
	) &&
	outer_one=$(make_tree \
		040000 outer $inner_one_a \
		040000 outer $inner_one_b
	) &&
	inner_two=$(make_tree \
		100644 inner $blob_one \
		100644 inner $blob_two \
		100644 inner $blob_two \
		100644 inner $blob_two
	) &&
	outer_two=$(make_tree \
		040000 outer $inner_two
	) &&
	shit tag one $outer_one &&
	shit tag two $outer_two
'

test_expect_success 'create tree without duplicate entries' '
	blob_one=$(echo one | shit hash-object -w --stdin) &&
	outer_three=$(make_tree \
		100644 renamed $blob_one
	) &&
	shit tag three $outer_three
'

test_expect_success 'diff-tree between duplicate trees' '
	# See NOTICE at top of file
	{
		printf ":000000 100644 $ZERO_OID $blob_two A\touter/inner\n" &&
		printf ":000000 100644 $ZERO_OID $blob_two A\touter/inner\n" &&
		printf ":000000 100644 $ZERO_OID $blob_two A\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n"
	} >expect &&
	shit diff-tree -r --no-abbrev one two >actual &&
	test_cmp expect actual
'

test_expect_success 'diff-tree with renames' '
	# See NOTICE at top of file.
	shit diff-tree -M -r --no-abbrev one two >actual &&
	test_must_be_empty actual
'

test_expect_success 'diff-tree FROM duplicate tree' '
	# See NOTICE at top of file.
	{
		printf ":100644 000000 $blob_one $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":000000 100644 $ZERO_OID $blob_one A\trenamed\n"
	} >expect &&
	shit diff-tree -r --no-abbrev one three >actual &&
	test_cmp expect actual
'

test_expect_success 'diff-tree FROM duplicate tree, with renames' '
	# See NOTICE at top of file.
	{
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 000000 $blob_two $ZERO_OID D\touter/inner\n" &&
		printf ":100644 100644 $blob_one $blob_one R100\touter/inner\trenamed\n"
	} >expect &&
	shit diff-tree -M -r --no-abbrev one three >actual &&
	test_cmp expect actual
'

test_expect_success 'create a few commits' '
	shit commit-tree -m "Duplicate Entries" two^{tree} >commit_id &&
	shit branch base $(cat commit_id) &&

	shit commit-tree -p $(cat commit_id) -m "Just one" three^{tree} >up &&
	shit branch update $(cat up) &&

	shit commit-tree -p $(cat up) -m "Back to weird" two^{tree} >final &&
	shit branch final $(cat final) &&

	rm commit_id up final
'

test_expect_failure 'shit read-tree does not segfault' '
	test_when_finished rm .shit/index.lock &&
	test_might_fail shit read-tree --reset base
'

test_expect_failure 'reset --hard does not segfault' '
	test_when_finished rm .shit/index.lock &&
	shit checkout base &&
	test_might_fail shit reset --hard
'

test_expect_failure 'shit diff HEAD does not segfault' '
	shit checkout base &&
	shit_TEST_CHECK_CACHE_TREE=false &&
	shit reset --hard &&
	test_might_fail shit diff HEAD
'

test_expect_failure 'can switch to another branch when status is empty' '
	shit clean -ffdqx &&
	shit status --porcelain -uno >actual &&
	test_must_be_empty actual &&
	shit checkout update
'

test_expect_success 'forcibly switch to another branch, verify status empty' '
	shit checkout -f update &&
	shit status --porcelain -uno >actual &&
	test_must_be_empty actual
'

test_expect_success 'fast-forward from non-duplicate entries to duplicate' '
	shit merge final
'

test_expect_failure 'clean status, switch branches, status still clean' '
	shit status --porcelain -uno >actual &&
	test_must_be_empty actual &&
	shit checkout base &&
	shit status --porcelain -uno >actual &&
	test_must_be_empty actual
'

test_expect_success 'switch to base branch and force status to be clean' '
	shit checkout base &&
	shit_TEST_CHECK_CACHE_TREE=false shit reset --hard &&
	shit status --porcelain -uno >actual &&
	test_must_be_empty actual
'

test_expect_failure 'fast-forward from duplicate entries to non-duplicate' '
	shit merge update
'

test_done
