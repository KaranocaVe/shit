#!/bin/sh

test_description='Tests pack performance using bitmaps (rev index enabled)'
. ./perf-lib.sh
. "${TEST_DIRECTORY}/perf/lib-bitmap.sh"

test_lookup_pack_bitmap () {
	test_expect_success 'start the test from scratch' '
		rm -rf * .shit
	'

	test_perf_large_repo

	test_expect_success 'setup bitmap config' '
		shit config pack.writebitmaps true
	'

	# we need to create the tag up front such that it is covered by the repack and
	# thus by generated bitmaps.
	test_expect_success 'create tags' '
		shit tag --message="tag pointing to HEAD" perf-tag HEAD
	'

	test_perf "enable lookup table: $1" '
		shit config pack.writeBitmapLookupTable '"$1"'
	'

	test_pack_bitmap
}

test_lookup_pack_bitmap false
test_lookup_pack_bitmap true

test_done
