#!/bin/sh

test_description='object name disambiguation

Create blobs, trees, commits and a tag that all share the same
prefix, and make sure "shit rev-parse" can take advantage of
type information to disambiguate short object names that are
not necessarily unique.

The final history used in the test has five commits, with the bottom
one tagged as v1.0.0.  They all have one regular file each.

  +-------------------------------------------+
  |                                           |
  |           .-------b3wettvi---- ad2uee     |
  |          /                   /            |
  |  a2onsxbvj---czy8f73t--ioiley5o           |
  |                                           |
  +-------------------------------------------+

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_cmp_failed_rev_parse () {
	dir=$1
	rev=$2

	cat >expect &&
	test_must_fail shit -C "$dir" rev-parse "$rev" 2>actual.raw &&
	sed "s/\($rev\)[0-9a-f]*/\1.../" <actual.raw >actual &&
	test_cmp expect actual
}

test_expect_success 'ambiguous blob output' '
	shit init --bare blob.prefix &&
	(
		cd blob.prefix &&

		# Both start with "dead..", under both SHA-1 and SHA-256
		echo brocdnra | shit hash-object -w --stdin &&
		echo brigddsv | shit hash-object -w --stdin &&

		# Both start with "beef.."
		echo 1agllotbh | shit hash-object -w --stdin &&
		echo 1bbfctrkc | shit hash-object -w --stdin
	) &&

	test_must_fail shit -C blob.prefix rev-parse dead &&
	test_cmp_failed_rev_parse blob.prefix beef <<-\EOF
	error: short object ID beef... is ambiguous
	hint: The candidates are:
	hint:   beef... blob
	hint:   beef... blob
	fatal: ambiguous argument '\''beef...'\'': unknown revision or path not in the working tree.
	Use '\''--'\'' to separate paths from revisions, like this:
	'\''shit <command> [<revision>...] -- [<file>...]'\''
	EOF
'

test_expect_success 'ambiguous loose bad object parsed as OBJ_BAD' '
	shit init --bare blob.bad &&
	(
		cd blob.bad &&

		# Both have the prefix "bad0"
		echo xyzfaowcoh | shit hash-object -t bad -w --stdin --literally &&
		echo xyzhjpyvwl | shit hash-object -t bad -w --stdin --literally
	) &&

	test_cmp_failed_rev_parse blob.bad bad0 <<-\EOF
	error: short object ID bad0... is ambiguous
	fatal: invalid object type
	EOF
'

test_expect_success POSIXPERM 'ambigous zlib corrupt loose blob' '
	shit init --bare blob.corrupt &&
	(
		cd blob.corrupt &&

		# Both have the prefix "cafe"
		echo bnkxmdwz | shit hash-object -w --stdin &&
		oid=$(echo bmwsjxzi | shit hash-object -w --stdin) &&

		oidf=objects/$(test_oid_to_path "$oid") &&
		chmod 755 $oidf &&
		echo broken >$oidf
	) &&

	test_cmp_failed_rev_parse blob.corrupt cafe <<-\EOF
	error: short object ID cafe... is ambiguous
	error: inflate: data stream error (incorrect header check)
	error: unable to unpack cafe... header
	error: inflate: data stream error (incorrect header check)
	error: unable to unpack cafe... header
	hint: The candidates are:
	hint:   cafe... [bad object]
	hint:   cafe... blob
	fatal: ambiguous argument '\''cafe...'\'': unknown revision or path not in the working tree.
	Use '\''--'\'' to separate paths from revisions, like this:
	'\''shit <command> [<revision>...] -- [<file>...]'\''
	EOF
'

if ! test_have_prereq SHA1
then
	skip_all='not using SHA-1 for objects'
	test_done
fi

test_expect_success 'blob and tree' '
	test_tick &&
	(
		test_write_lines 0 1 2 3 4 5 6 7 8 9 &&
		echo &&
		echo b1rwzyc3
	) >a0blgqsjc &&

	# create one blob 0000000000b36
	shit add a0blgqsjc &&

	# create one tree 0000000000cdc
	shit write-tree
'

test_expect_success 'warn ambiguity when no candidate matches type hint' '
	test_must_fail shit rev-parse --verify 000000000^{commit} 2>actual &&
	test_grep "short object ID 000000000 is ambiguous" actual
'

test_expect_success 'disambiguate tree-ish' '
	# feed tree-ish in an unambiguous way
	shit rev-parse --verify 0000000000cdc:a0blgqsjc &&

	# ambiguous at the object name level, but there is only one
	# such tree-ish (the other is a blob)
	shit rev-parse --verify 000000000:a0blgqsjc
'

test_expect_success 'disambiguate blob' '
	sed -e "s/|$//" >patch <<-EOF &&
	diff --shit a/frotz b/frotz
	index 000000000..ffffff 100644
	--- a/frotz
	+++ b/frotz
	@@ -10,3 +10,4 @@
	 9
	 |
	 b1rwzyc3
	+irwry
	EOF
	(
		shit_INDEX_FILE=frotz &&
		export shit_INDEX_FILE &&
		shit apply --build-fake-ancestor frotz patch &&
		shit cat-file blob :frotz >actual
	) &&
	test_cmp a0blgqsjc actual
'

test_expect_success 'disambiguate tree' '
	commit=$(echo "d7xm" | shit commit-tree 000000000) &&
	# this commit is fffff2e and not ambiguous with the 00000* objects
	test $(shit rev-parse $commit^{tree}) = $(shit rev-parse 0000000000cdc)
'

test_expect_success 'first commit' '
	# create one commit 0000000000e4f
	shit commit -m a2onsxbvj
'

test_expect_success 'disambiguate commit-ish' '
	# feed commit-ish in an unambiguous way
	shit rev-parse --verify 0000000000e4f^{commit} &&

	# ambiguous at the object name level, but there is only one
	# such commit (the others are tree and blob)
	shit rev-parse --verify 000000000^{commit} &&

	# likewise
	shit rev-parse --verify 000000000^0
'

test_expect_success 'disambiguate commit' '
	commit=$(echo "hoaxj" | shit commit-tree 0000000000cdc -p 000000000) &&
	# this commit is ffffffd8 and not ambiguous with the 00000* objects
	test $(shit rev-parse $commit^) = $(shit rev-parse 0000000000e4f)
'

test_expect_success 'log name1..name2 takes only commit-ishes on both ends' '
	# These are underspecified from the prefix-length point of view
	# to disambiguate the commit with other objects, but there is only
	# one commit that has 00000* prefix at this point.
	shit log 000000000..000000000 &&
	shit log ..000000000 &&
	shit log 000000000.. &&
	shit log 000000000...000000000 &&
	shit log ...000000000 &&
	shit log 000000000...
'

test_expect_success 'rev-parse name1..name2 takes only commit-ishes on both ends' '
	# Likewise.
	shit rev-parse 000000000..000000000 &&
	shit rev-parse ..000000000 &&
	shit rev-parse 000000000..
'

test_expect_success 'shit log takes only commit-ish' '
	# Likewise.
	shit log 000000000
'

test_expect_success 'shit reset takes only commit-ish' '
	# Likewise.
	shit reset 000000000
'

test_expect_success 'first tag' '
	# create one tag 0000000000f8f
	shit tag -a -m j7cp83um v1.0.0
'

test_expect_failure 'two semi-ambiguous commit-ish' '
	# At this point, we have a tag 0000000000f8f that points
	# at a commit 0000000000e4f, and a tree and a blob that
	# share 0000000000 prefix with these tag and commit.
	#
	# Once the parser becomes ultra-smart, it could notice that
	# 0000000000 before ^{commit} name many different objects, but
	# that only two (HEAD and v1.0.0 tag) can be peeled to commit,
	# and that peeling them down to commit yield the same commit
	# without ambiguity.
	shit rev-parse --verify 0000000000^{commit} &&

	# likewise
	shit log 0000000000..0000000000 &&
	shit log ..0000000000 &&
	shit log 0000000000.. &&
	shit log 0000000000...0000000000 &&
	shit log ...0000000000 &&
	shit log 0000000000...
'

test_expect_failure 'three semi-ambiguous tree-ish' '
	# Likewise for tree-ish.  HEAD, v1.0.0 and HEAD^{tree} share
	# the prefix but peeling them to tree yields the same thing
	shit rev-parse --verify 0000000000^{tree}
'

test_expect_success 'parse describe name' '
	# feed an unambiguous describe name
	shit rev-parse --verify v1.0.0-0-g0000000000e4f &&

	# ambiguous at the object name level, but there is only one
	# such commit (others are blob, tree and tag)
	shit rev-parse --verify v1.0.0-0-g000000000
'

test_expect_success 'more history' '
	# commit 0000000000043
	shit mv a0blgqsjc d12cr3h8t &&
	echo h62xsjeu >>d12cr3h8t &&
	shit add d12cr3h8t &&

	test_tick &&
	shit commit -m czy8f73t &&

	# commit 00000000008ec
	shit mv d12cr3h8t j000jmpzn &&
	echo j08bekfvt >>j000jmpzn &&
	shit add j000jmpzn &&

	test_tick &&
	shit commit -m ioiley5o &&

	# commit 0000000005b0
	shit checkout v1.0.0^0 &&
	shit mv a0blgqsjc f5518nwu &&

	test_write_lines h62xsjeu j08bekfvt kg7xflhm >>f5518nwu &&
	shit add f5518nwu &&

	test_tick &&
	shit commit -m b3wettvi &&
	side=$(shit rev-parse HEAD) &&

	# commit 000000000066
	shit checkout main &&

	# If you use recursive, merge will fail and you will need to
	# clean up a0blgqsjc as well.  If you use resolve, merge will
	# succeed.
	test_might_fail shit merge --no-commit -s recursive $side &&
	shit rm -f f5518nwu j000jmpzn &&

	test_might_fail shit rm -f a0blgqsjc &&
	(
		shit cat-file blob $side:f5518nwu &&
		echo j3l0i9s6
	) >ab2gs879 &&
	shit add ab2gs879 &&

	test_tick &&
	shit commit -m ad2uee

'

test_expect_failure 'parse describe name taking advantage of generation' '
	# ambiguous at the object name level, but there is only one
	# such commit at generation 0
	shit rev-parse --verify v1.0.0-0-g000000000 &&

	# likewise for generation 2 and 4
	shit rev-parse --verify v1.0.0-2-g000000000 &&
	shit rev-parse --verify v1.0.0-4-g000000000
'

# Note: because rev-parse does not even try to disambiguate based on
# the generation number, this test currently succeeds for a wrong
# reason.  When it learns to use the generation number, the previous
# test should succeed, and also this test should fail because the
# describe name used in the test with generation number can name two
# commits.  Make sure that such a future enhancement does not randomly
# pick one.
test_expect_success 'parse describe name not ignoring ambiguity' '
	# ambiguous at the object name level, and there are two such
	# commits at generation 1
	test_must_fail shit rev-parse --verify v1.0.0-1-g000000000
'

test_expect_success 'ambiguous commit-ish' '
	# Now there are many commits that begin with the
	# common prefix, none of these should pick one at
	# random.  They all should result in ambiguity errors.
	test_must_fail shit rev-parse --verify 00000000^{commit} &&

	# likewise
	test_must_fail shit log 000000000..000000000 &&
	test_must_fail shit log ..000000000 &&
	test_must_fail shit log 000000000.. &&
	test_must_fail shit log 000000000...000000000 &&
	test_must_fail shit log ...000000000 &&
	test_must_fail shit log 000000000...
'

# There are three objects with this prefix: a blob, a tree, and a tag. We know
# the blob will not pass as a treeish, but the tree and tag should (and thus
# cause an error).
test_expect_success 'ambiguous tags peel to treeish' '
	test_must_fail shit rev-parse 0000000000f^{tree}
'

test_expect_success 'rev-parse --disambiguate' '
	# The test creates 16 objects that share the prefix and two
	# commits created by commit-tree in earlier tests share a
	# different prefix.
	shit rev-parse --disambiguate=000000000 >actual &&
	test_line_count = 16 actual &&
	test "$(sed -e "s/^\(.........\).*/\1/" actual | sort -u)" = 000000000
'

test_expect_success 'rev-parse --disambiguate drops duplicates' '
	shit rev-parse --disambiguate=000000000 >expect &&
	shit pack-objects .shit/objects/pack/pack <expect &&
	shit rev-parse --disambiguate=000000000 >actual &&
	test_cmp expect actual
'

test_expect_success 'ambiguous 40-hex ref' '
	TREE=$(shit mktree </dev/null) &&
	REF=$(shit rev-parse HEAD) &&
	VAL=$(shit commit-tree $TREE </dev/null) &&
	shit update-ref refs/heads/$REF $VAL &&
	test $(shit rev-parse $REF 2>err) = $REF &&
	grep "refname.*${REF}.*ambiguous" err
'

test_expect_success 'ambiguous short sha1 ref' '
	TREE=$(shit mktree </dev/null) &&
	REF=$(shit rev-parse --short HEAD) &&
	VAL=$(shit commit-tree $TREE </dev/null) &&
	shit update-ref refs/heads/$REF $VAL &&
	test $(shit rev-parse $REF 2>err) = $VAL &&
	grep "refname.*${REF}.*ambiguous" err
'

test_expect_success 'ambiguity errors are not repeated (raw)' '
	test_must_fail shit rev-parse 00000 2>stderr &&
	grep "is ambiguous" stderr >errors &&
	test_line_count = 1 errors
'

test_expect_success 'ambiguity errors are not repeated (treeish)' '
	test_must_fail shit rev-parse 00000:foo 2>stderr &&
	grep "is ambiguous" stderr >errors &&
	test_line_count = 1 errors
'

test_expect_success 'ambiguity errors are not repeated (peel)' '
	test_must_fail shit rev-parse 00000^{commit} 2>stderr &&
	grep "is ambiguous" stderr >errors &&
	test_line_count = 1 errors
'

test_expect_success 'ambiguity hints' '
	test_must_fail shit rev-parse 000000000 2>stderr &&
	grep ^hint: stderr >hints &&
	# 16 candidates, plus one intro line
	test_line_count = 17 hints
'

test_expect_success 'ambiguity hints respect type' '
	test_must_fail shit rev-parse 000000000^{commit} 2>stderr &&
	grep ^hint: stderr >hints &&
	# 5 commits, 1 tag (which is a committish), plus intro line
	test_line_count = 7 hints
'

test_expect_success 'failed type-selector still shows hint' '
	# these two blobs share the same prefix "ee3d", but neither
	# will pass for a commit
	echo 851 | shit hash-object --stdin -w &&
	echo 872 | shit hash-object --stdin -w &&
	test_must_fail shit rev-parse ee3d^{commit} 2>stderr &&
	grep ^hint: stderr >hints &&
	test_line_count = 3 hints
'

test_expect_success 'core.disambiguate config can prefer types' '
	# ambiguous between tree and tag
	sha1=0000000000f &&
	test_must_fail shit rev-parse $sha1 &&
	shit rev-parse $sha1^{commit} &&
	shit -c core.disambiguate=committish rev-parse $sha1
'

test_expect_success 'core.disambiguate does not override context' '
	# treeish ambiguous between tag and tree
	test_must_fail \
		shit -c core.disambiguate=committish rev-parse $sha1^{tree}
'

test_expect_success 'ambiguous commits are printed by type first, then hash order' '
	test_must_fail shit rev-parse 0000 2>stderr &&
	grep ^hint: stderr >hints &&
	grep 0000 hints >objects &&
	cat >expected <<-\EOF &&
	tag
	commit
	tree
	blob
	EOF
	awk "{print \$3}" <objects >objects.types &&
	uniq <objects.types >objects.types.uniq &&
	test_cmp expected objects.types.uniq &&
	for type in tag commit tree blob
	do
		grep $type objects >$type.objects &&
		sort $type.objects >$type.objects.sorted &&
		test_cmp $type.objects.sorted $type.objects || return 1
	done
'

test_expect_success 'cat-file --batch and --batch-check show ambiguous' '
	echo "0000 ambiguous" >expect &&
	echo 0000 | shit cat-file --batch-check >actual 2>err &&
	test_cmp expect actual &&
	test_grep hint: err &&
	echo 0000 | shit cat-file --batch >actual 2>err &&
	test_cmp expect actual &&
	test_grep hint: err
'

test_done
