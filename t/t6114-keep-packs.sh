#!/bin/sh

test_description='rev-list with .keep packs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit loose &&
	test_commit packed &&
	test_commit kept &&

	KEPT_PACK=$(shit pack-objects --revs .shit/objects/pack/pack <<-EOF
	refs/tags/kept
	^refs/tags/packed
	EOF
	) &&
	MISC_PACK=$(shit pack-objects --revs .shit/objects/pack/pack <<-EOF
	refs/tags/packed
	^refs/tags/loose
	EOF
	) &&

	touch .shit/objects/pack/pack-$KEPT_PACK.keep
'

rev_list_objects () {
	shit rev-list "$@" >out &&
	sort out
}

idx_objects () {
	shit show-index <$1 >expect-idx &&
	cut -d" " -f2 <expect-idx | sort
}

test_expect_success '--no-kept-objects excludes trees and blobs in .keep packs' '
	rev_list_objects --objects --all --no-object-names >kept &&
	rev_list_objects --objects --all --no-object-names --no-kept-objects >no-kept &&

	idx_objects .shit/objects/pack/pack-$KEPT_PACK.idx >expect &&
	comm -3 kept no-kept >actual &&

	test_cmp expect actual
'

test_expect_success '--no-kept-objects excludes kept non-MIDX object' '
	test_config core.multiPackIndex true &&

	# Create a pack with just the commit object in pack, and do not mark it
	# as kept (even though it appears in $KEPT_PACK, which does have a .keep
	# file).
	MIDX_PACK=$(shit pack-objects .shit/objects/pack/pack <<-EOF
	$(shit rev-parse kept)
	EOF
	) &&

	# Write a MIDX containing all packs, but use the version of the commit
	# at "kept" in a non-kept pack by touching $MIDX_PACK.
	touch .shit/objects/pack/pack-$MIDX_PACK.pack &&
	shit multi-pack-index write &&

	rev_list_objects --objects --no-object-names --no-kept-objects HEAD >actual &&
	(
		idx_objects .shit/objects/pack/pack-$MISC_PACK.idx &&
		shit rev-list --objects --no-object-names refs/tags/loose
	) | sort >expect &&
	test_cmp expect actual
'

test_done
