#!/bin/sh

test_description='exercise basic bitmap functionality'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-bitmap.sh

# t5310 deals only with single-pack bitmaps, so don't write MIDX bitmaps in
# their place.
shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0

# Likewise, allow individual tests to control whether or not they use
# the boundary-based traversal.
sane_unset shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL

objpath () {
	echo ".shit/objects/$(echo "$1" | sed -e 's|\(..\)|\1/|')"
}

# show objects present in pack ($1 should be associated *.idx)
list_packed_objects () {
	shit show-index <"$1" >object-list &&
	cut -d' ' -f2 object-list
}

# has_any pattern-file content-file
# tests whether content-file has any entry from pattern-file with entries being
# whole lines.
has_any () {
	grep -Ff "$1" "$2"
}

test_bitmap_cases () {
	writeLookupTable=false
	for i in "$@"
	do
		case "$i" in
		"pack.writeBitmapLookupTable") writeLookupTable=true;;
		esac
	done

	test_expect_success 'setup test repository' '
		rm -fr * .shit &&
		shit init &&
		shit config pack.writeBitmapLookupTable '"$writeLookupTable"'
	'
	setup_bitmap_history

	test_expect_success 'setup writing bitmaps during repack' '
		shit config repack.writeBitmaps true
	'

	test_expect_success 'full repack creates bitmaps' '
		shit_TRACE2_EVENT="$(pwd)/trace" \
			shit repack -ad &&
		ls .shit/objects/pack/ | grep bitmap >output &&
		test_line_count = 1 output &&
		grep "\"key\":\"num_selected_commits\",\"value\":\"106\"" trace &&
		grep "\"key\":\"num_maximal_commits\",\"value\":\"107\"" trace
	'

	basic_bitmap_tests

	test_expect_success 'pack-objects respects --local (non-local loose)' '
		shit init --bare alt.shit &&
		echo $(pwd)/alt.shit/objects >.shit/objects/info/alternates &&
		echo content1 >file1 &&
		# non-local loose object which is not present in bitmapped pack
		altblob=$(shit_DIR=alt.shit shit hash-object -w file1) &&
		# non-local loose object which is also present in bitmapped pack
		shit cat-file blob $blob | shit_DIR=alt.shit shit hash-object -w --stdin &&
		shit add file1 &&
		test_tick &&
		shit commit -m commit_file1 &&
		echo HEAD | shit pack-objects --local --stdout --revs >1.pack &&
		shit index-pack 1.pack &&
		list_packed_objects 1.idx >1.objects &&
		printf "%s\n" "$altblob" "$blob" >nonlocal-loose &&
		! has_any nonlocal-loose 1.objects
	'

	test_expect_success 'pack-objects respects --honor-pack-keep (local non-bitmapped pack)' '
		echo content2 >file2 &&
		blob2=$(shit hash-object -w file2) &&
		shit add file2 &&
		test_tick &&
		shit commit -m commit_file2 &&
		printf "%s\n" "$blob2" "$bitmaptip" >keepobjects &&
		pack2=$(shit pack-objects pack2 <keepobjects) &&
		mv pack2-$pack2.* .shit/objects/pack/ &&
		>.shit/objects/pack/pack2-$pack2.keep &&
		rm $(objpath $blob2) &&
		echo HEAD | shit pack-objects --honor-pack-keep --stdout --revs >2a.pack &&
		shit index-pack 2a.pack &&
		list_packed_objects 2a.idx >2a.objects &&
		! has_any keepobjects 2a.objects
	'

	test_expect_success 'pack-objects respects --local (non-local pack)' '
		mv .shit/objects/pack/pack2-$pack2.* alt.shit/objects/pack/ &&
		echo HEAD | shit pack-objects --local --stdout --revs >2b.pack &&
		shit index-pack 2b.pack &&
		list_packed_objects 2b.idx >2b.objects &&
		! has_any keepobjects 2b.objects
	'

	test_expect_success 'pack-objects respects --honor-pack-keep (local bitmapped pack)' '
		ls .shit/objects/pack/ | grep bitmap >output &&
		test_line_count = 1 output &&
		packbitmap=$(basename $(cat output) .bitmap) &&
		list_packed_objects .shit/objects/pack/$packbitmap.idx >packbitmap.objects &&
		test_when_finished "rm -f .shit/objects/pack/$packbitmap.keep" &&
		>.shit/objects/pack/$packbitmap.keep &&
		echo HEAD | shit pack-objects --honor-pack-keep --stdout --revs >3a.pack &&
		shit index-pack 3a.pack &&
		list_packed_objects 3a.idx >3a.objects &&
		! has_any packbitmap.objects 3a.objects
	'

	test_expect_success 'pack-objects respects --local (non-local bitmapped pack)' '
		mv .shit/objects/pack/$packbitmap.* alt.shit/objects/pack/ &&
		rm -f .shit/objects/pack/multi-pack-index &&
		test_when_finished "mv alt.shit/objects/pack/$packbitmap.* .shit/objects/pack/" &&
		echo HEAD | shit pack-objects --local --stdout --revs >3b.pack &&
		shit index-pack 3b.pack &&
		list_packed_objects 3b.idx >3b.objects &&
		! has_any packbitmap.objects 3b.objects
	'

	test_expect_success 'pack-objects to file can use bitmap' '
		# make sure we still have 1 bitmap index from previous tests
		ls .shit/objects/pack/ | grep bitmap >output &&
		test_line_count = 1 output &&
		# verify equivalent packs are generated with/without using bitmap index
		packasha1=$(shit pack-objects --no-use-bitmap-index --all packa </dev/null) &&
		packbsha1=$(shit pack-objects --use-bitmap-index --all packb </dev/null) &&
		list_packed_objects packa-$packasha1.idx >packa.objects &&
		list_packed_objects packb-$packbsha1.idx >packb.objects &&
		test_cmp packa.objects packb.objects
	'

	test_expect_success 'full repack, reusing previous bitmaps' '
		shit repack -ad &&
		ls .shit/objects/pack/ | grep bitmap >output &&
		test_line_count = 1 output
	'

	test_expect_success 'fetch (full bitmap)' '
		shit --shit-dir=clone.shit fetch origin second:second &&
		shit rev-parse HEAD >expect &&
		shit --shit-dir=clone.shit rev-parse HEAD >actual &&
		test_cmp expect actual
	'

	test_expect_success 'create objects for missing-HAVE tests' '
		blob=$(echo "missing have" | shit hash-object -w --stdin) &&
		tree=$(printf "100644 blob $blob\tfile\n" | shit mktree) &&
		parent=$(echo parent | shit commit-tree $tree) &&
		commit=$(echo commit | shit commit-tree $tree -p $parent) &&
		cat >revs <<-EOF
		HEAD
		^HEAD^
		^$commit
		EOF
	'

	test_expect_success 'pack-objects respects --incremental' '
		cat >revs2 <<-EOF &&
		HEAD
		$commit
		EOF
		shit pack-objects --incremental --stdout --revs <revs2 >4.pack &&
		shit index-pack 4.pack &&
		list_packed_objects 4.idx >4.objects &&
		test_line_count = 4 4.objects &&
		shit rev-list --objects $commit >revlist &&
		cut -d" " -f1 revlist |sort >objects &&
		test_cmp 4.objects objects
	'

	test_expect_success 'pack with missing blob' '
		rm $(objpath $blob) &&
		shit pack-objects --stdout --revs <revs >/dev/null
	'

	test_expect_success 'pack with missing tree' '
		rm $(objpath $tree) &&
		shit pack-objects --stdout --revs <revs >/dev/null
	'

	test_expect_success 'pack with missing parent' '
		rm $(objpath $parent) &&
		shit pack-objects --stdout --revs <revs >/dev/null
	'

	test_expect_success Jshit,SHA1 'we can read jshit bitmaps' '
		shit clone --bare . compat-jshit.shit &&
		(
			cd compat-jshit.shit &&
			rm -f objects/pack/*.bitmap &&
			jshit gc &&
			shit rev-list --test-bitmap HEAD
		)
	'

	test_expect_success Jshit,SHA1 'jshit can read our bitmaps' '
		shit clone --bare . compat-us.shit &&
		(
			cd compat-us.shit &&
			shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&
			shit repack -adb &&
			# jshit gc will barf if it does not like our bitmaps
			jshit gc
		)
	'

	test_expect_success 'splitting packs does not generate bogus bitmaps' '
		test-tool genrandom foo $((1024 * 1024)) >rand &&
		shit add rand &&
		shit commit -m "commit with big file" &&
		shit -c pack.packSizeLimit=500k repack -adb &&
		shit init --bare no-bitmaps.shit &&
		shit -C no-bitmaps.shit fetch .. HEAD
	'

	test_expect_success 'set up reusable pack' '
		rm -f .shit/objects/pack/*.keep &&
		shit repack -adb &&
		reusable_pack () {
			shit for-each-ref --format="%(objectname)" |
			shit pack-objects --delta-base-offset --revs --stdout "$@"
		}
	'

	test_expect_success 'pack reuse respects --honor-pack-keep' '
		test_when_finished "rm -f .shit/objects/pack/*.keep" &&
		for i in .shit/objects/pack/*.pack
		do
			>${i%.pack}.keep || return 1
		done &&
		reusable_pack --honor-pack-keep >empty.pack &&
		shit index-pack empty.pack &&
		shit show-index <empty.idx >actual &&
		test_must_be_empty actual
	'

	test_expect_success 'pack reuse respects --local' '
		mv .shit/objects/pack/* alt.shit/objects/pack/ &&
		test_when_finished "mv alt.shit/objects/pack/* .shit/objects/pack/" &&
		reusable_pack --local >empty.pack &&
		shit index-pack empty.pack &&
		shit show-index <empty.idx >actual &&
		test_must_be_empty actual
	'

	test_expect_success 'pack reuse respects --incremental' '
		reusable_pack --incremental >empty.pack &&
		shit index-pack empty.pack &&
		shit show-index <empty.idx >actual &&
		test_must_be_empty actual
	'

	test_expect_success 'truncated bitmap fails gracefully (ewah)' '
		test_config pack.writebitmaphashcache false &&
		test_config pack.writebitmaplookuptable false &&
		shit repack -ad &&
		shit rev-list --use-bitmap-index --count --all >expect &&
		bitmap=$(ls .shit/objects/pack/*.bitmap) &&
		test_when_finished "rm -f $bitmap" &&
		test_copy_bytes 256 <$bitmap >$bitmap.tmp &&
		mv -f $bitmap.tmp $bitmap &&
		shit rev-list --use-bitmap-index --count --all >actual 2>stderr &&
		test_cmp expect actual &&
		test_grep corrupt.ewah.bitmap stderr
	'

	test_expect_success 'truncated bitmap fails gracefully (cache)' '
		shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&
		shit repack -ad &&
		shit rev-list --use-bitmap-index --count --all >expect &&
		bitmap=$(ls .shit/objects/pack/*.bitmap) &&
		test_when_finished "rm -f $bitmap" &&
		test_copy_bytes 512 <$bitmap >$bitmap.tmp &&
		mv -f $bitmap.tmp $bitmap &&
		shit rev-list --use-bitmap-index --count --all >actual 2>stderr &&
		test_cmp expect actual &&
		test_grep corrupted.bitmap.index stderr
	'

	# Create a state of history with these properties:
	#
	#  - refs that allow a client to fetch some new history, while sharing some old
	#    history with the server; we use branches delta-reuse-old and
	#    delta-reuse-new here
	#
	#  - the new history contains an object that is stored on the server as a delta
	#    against a base that is in the old history
	#
	#  - the base object is not immediately reachable from the tip of the old
	#    history; finding it would involve digging down through history we know the
	#    other side has
	#
	# This should result in a state where fetching from old->new would not
	# traditionally reuse the on-disk delta (because we'd have to dig to realize
	# that the client has it), but we will do so if bitmaps can tell us cheaply
	# that the other side has it.
	test_expect_success 'set up thin delta-reuse parent' '
		# This first commit contains the buried base object.
		test-tool genrandom delta 16384 >file &&
		shit add file &&
		shit commit -m "delta base" &&
		base=$(shit rev-parse --verify HEAD:file) &&

		# These intermediate commits bury the base back in history.
		# This becomes the "old" state.
		for i in 1 2 3 4 5
		do
			echo $i >file &&
			shit commit -am "intermediate $i" || return 1
		done &&
		shit branch delta-reuse-old &&

		# And now our new history has a delta against the buried base. Note
		# that this must be smaller than the original file, since pack-objects
		# prefers to create deltas from smaller objects to larger.
		test-tool genrandom delta 16300 >file &&
		shit commit -am "delta result" &&
		delta=$(shit rev-parse --verify HEAD:file) &&
		shit branch delta-reuse-new &&

		# Repack with bitmaps and double check that we have the expected delta
		# relationship.
		shit repack -adb &&
		have_delta $delta $base
	'

	# Now we can sanity-check the non-bitmap behavior (that the server is not able
	# to reuse the delta). This isn't strictly something we care about, so this
	# test could be scrapped in the future. But it makes sure that the next test is
	# actually triggering the feature we want.
	#
	# Note that our tools for working with on-the-wire "thin" packs are limited. So
	# we actually perform the fetch, retain the resulting pack, and inspect the
	# result.
	test_expect_success 'fetch without bitmaps ignores delta against old base' '
		test_config pack.usebitmaps false &&
		test_when_finished "rm -rf client.shit" &&
		shit init --bare client.shit &&
		(
			cd client.shit &&
			shit config transfer.unpackLimit 1 &&
			shit fetch .. delta-reuse-old:delta-reuse-old &&
			shit fetch .. delta-reuse-new:delta-reuse-new &&
			have_delta $delta $ZERO_OID
		)
	'

	# And do the same for the bitmap case, where we do expect to find the delta.
	test_expect_success 'fetch with bitmaps can reuse old base' '
		test_config pack.usebitmaps true &&
		test_when_finished "rm -rf client.shit" &&
		shit init --bare client.shit &&
		(
			cd client.shit &&
			shit config transfer.unpackLimit 1 &&
			shit fetch .. delta-reuse-old:delta-reuse-old &&
			shit fetch .. delta-reuse-new:delta-reuse-new &&
			have_delta $delta $base
		)
	'

	test_expect_success 'pack.preferBitmapTips' '
		shit init repo &&
		test_when_finished "rm -fr repo" &&
		(
			cd repo &&
			shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&

			# create enough commits that not all are receive bitmap
			# coverage even if they are all at the tip of some reference.
			test_commit_bulk --message="%s" 103 &&

			shit rev-list HEAD >commits.raw &&
			sort <commits.raw >commits &&

			shit log --format="create refs/tags/%s %H" HEAD >refs &&
			shit update-ref --stdin <refs &&

			shit repack -adb &&
			test-tool bitmap list-commits | sort >bitmaps &&

			# remember which commits did not receive bitmaps
			comm -13 bitmaps commits >before &&
			test_file_not_empty before &&

			# mark the commits which did not receive bitmaps as preferred,
			# and generate the bitmap again
			perl -pe "s{^}{create refs/tags/include/$. }" <before |
				shit update-ref --stdin &&
			shit -c pack.preferBitmapTips=refs/tags/include repack -adb &&

			# finally, check that the commit(s) without bitmap coverage
			# are not the same ones as before
			test-tool bitmap list-commits | sort >bitmaps &&
			comm -13 bitmaps commits >after &&

			! test_cmp before after
		)
	'

	test_expect_success 'pack.preferBitmapTips' '
		shit init repo &&
		test_when_finished "rm -rf repo" &&
		(
			cd repo &&
			shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&
			test_commit_bulk --message="%s" 103 &&

			cat >>.shit/config <<-\EOF &&
			[pack]
				preferBitmapTips
			EOF
			cat >expect <<-\EOF &&
			error: missing value for '\''pack.preferbitmaptips'\''
			EOF
			shit repack -adb 2>actual &&
			test_cmp expect actual
		)
	'

	test_expect_success 'complains about multiple pack bitmaps' '
		rm -fr repo &&
		shit init repo &&
		test_when_finished "rm -fr repo" &&
		(
			cd repo &&
			shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&

			test_commit base &&

			shit repack -adb &&
			bitmap="$(ls .shit/objects/pack/pack-*.bitmap)" &&
			mv "$bitmap" "$bitmap.bak" &&

			test_commit other &&
			shit repack -ab &&

			mv "$bitmap.bak" "$bitmap" &&

			find .shit/objects/pack -type f -name "*.pack" >packs &&
			find .shit/objects/pack -type f -name "*.bitmap" >bitmaps &&
			test_line_count = 2 packs &&
			test_line_count = 2 bitmaps &&

			shit_TRACE2_EVENT=$(pwd)/trace2.txt shit rev-list --use-bitmap-index HEAD &&
			grep "opened bitmap" trace2.txt &&
			grep "ignoring extra bitmap" trace2.txt
		)
	'
}

test_bitmap_cases

shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL=1
export shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL

test_bitmap_cases

sane_unset shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL

test_expect_success 'incremental repack fails when bitmaps are requested' '
	test_commit more-1 &&
	test_must_fail shit repack -d 2>err &&
	test_grep "Incremental repacks are incompatible with bitmap" err
'

test_expect_success 'incremental repack can disable bitmaps' '
	test_commit more-2 &&
	shit repack -d --no-write-bitmap-index
'

test_expect_success 'boundary-based traversal is used when requested' '
	shit repack -a -d --write-bitmap-index &&

	for argv in \
		"shit -c pack.useBitmapBoundaryTraversal=true" \
		"shit -c feature.experimental=true" \
		"shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL=1 shit"
	do
		eval "shit_TRACE2_EVENT=1 $argv rev-list --objects \
			--use-bitmap-index second..other 2>perf" &&
		grep "\"region_enter\".*\"label\":\"haves/boundary\"" perf ||
			return 1
	done &&

	for argv in \
		"shit -c pack.useBitmapBoundaryTraversal=false" \
		"shit -c feature.experimental=true -c pack.useBitmapBoundaryTraversal=false" \
		"shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL=0 shit -c pack.useBitmapBoundaryTraversal=true" \
		"shit_TEST_PACK_USE_BITMAP_BOUNDARY_TRAVERSAL=0 shit -c feature.experimental=true"
	do
		eval "shit_TRACE2_EVENT=1 $argv rev-list --objects \
			--use-bitmap-index second..other 2>perf" &&
		grep "\"region_enter\".*\"label\":\"haves/classic\"" perf ||
			return 1
	done
'

test_bitmap_cases "pack.writeBitmapLookupTable"

test_expect_success 'verify writing bitmap lookup table when enabled' '
	shit_TRACE2_EVENT="$(pwd)/trace2" \
		shit repack -ad &&
	grep "\"label\":\"writing_lookup_table\"" trace2
'

test_expect_success 'truncated bitmap fails gracefully (lookup table)' '
	test_config pack.writebitmaphashcache false &&
	shit repack -adb &&
	shit rev-list --use-bitmap-index --count --all >expect &&
	bitmap=$(ls .shit/objects/pack/*.bitmap) &&
	test_when_finished "rm -f $bitmap" &&
	test_copy_bytes 512 <$bitmap >$bitmap.tmp &&
	mv -f $bitmap.tmp $bitmap &&
	shit rev-list --use-bitmap-index --count --all >actual 2>stderr &&
	test_cmp expect actual &&
	test_grep corrupted.bitmap.index stderr
'

test_done
