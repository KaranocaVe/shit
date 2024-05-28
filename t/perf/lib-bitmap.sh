# Helper functions for testing bitmap performance; see p5310.

test_full_bitmap () {
	test_perf 'simulated clone' '
		shit pack-objects --stdout --all </dev/null >/dev/null
	'

	test_perf 'simulated fetch' '
		have=$(shit rev-list HEAD~100 -1) &&
		{
			echo HEAD &&
			echo ^$have
		} | shit pack-objects --revs --stdout >/dev/null
	'

	test_perf 'pack to file (bitmap)' '
		shit pack-objects --use-bitmap-index --all pack1b </dev/null >/dev/null
	'

	test_perf 'rev-list (commits)' '
		shit rev-list --all --use-bitmap-index >/dev/null
	'

	test_perf 'rev-list (objects)' '
		shit rev-list --all --use-bitmap-index --objects >/dev/null
	'

	test_perf 'rev-list with tag negated via --not --all (objects)' '
		shit rev-list perf-tag --not --all --use-bitmap-index --objects >/dev/null
	'

	test_perf 'rev-list with negative tag (objects)' '
		shit rev-list HEAD --not perf-tag --use-bitmap-index --objects >/dev/null
	'

	test_perf 'rev-list count with blob:none' '
		shit rev-list --use-bitmap-index --count --objects --all \
			--filter=blob:none >/dev/null
	'

	test_perf 'rev-list count with blob:limit=1k' '
		shit rev-list --use-bitmap-index --count --objects --all \
			--filter=blob:limit=1k >/dev/null
	'

	test_perf 'rev-list count with tree:0' '
		shit rev-list --use-bitmap-index --count --objects --all \
			--filter=tree:0 >/dev/null
	'

	test_perf 'simulated partial clone' '
		shit pack-objects --stdout --all --filter=blob:none </dev/null >/dev/null
	'
}

test_partial_bitmap () {
	test_perf 'clone (partial bitmap)' '
		shit pack-objects --stdout --all </dev/null >/dev/null
	'

	test_perf 'pack to file (partial bitmap)' '
		shit pack-objects --use-bitmap-index --all pack2b </dev/null >/dev/null
	'

	test_perf 'rev-list with tree filter (partial bitmap)' '
		shit rev-list --use-bitmap-index --count --objects --all \
			--filter=tree:0 >/dev/null
	'
}

test_pack_bitmap () {
	test_perf "repack to disk" '
		shit repack -ad
	'

	test_full_bitmap

	test_expect_success "create partial bitmap state" '
		# pick a commit to represent the repo tip in the past
		cutoff=$(shit rev-list HEAD~100 -1) &&
		orig_tip=$(shit rev-parse HEAD) &&

		# now kill off all of the refs and pretend we had
		# just the one tip
		rm -rf .shit/logs .shit/refs/* .shit/packed-refs &&
		shit update-ref HEAD $cutoff &&

		# and then repack, which will leave us with a nice
		# big bitmap pack of the "old" history, and all of
		# the new history will be loose, as if it had been defecateed
		# up incrementally and exploded via unpack-objects
		shit repack -Ad &&

		# and now restore our original tip, as if the defecatees
		# had happened
		shit update-ref HEAD $orig_tip
	'

	test_partial_bitmap
}
