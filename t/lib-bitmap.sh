# Helpers for scripts testing bitmap functionality; see t5310 for
# example usage.

objdir=.shit/objects
midx=$objdir/pack/multi-pack-index

# Compare a file containing rev-list bitmap traversal output to its non-bitmap
# counterpart. You can't just use test_cmp for this, because the two produce
# subtly different output:
#
#   - regular output is in traversal order, whereas bitmap is split by type,
#     with non-packed objects at the end
#
#   - regular output has a space and the pathname appended to non-commit
#     objects; bitmap output omits this
#
# This function normalizes and compares the two. The second file should
# always be the bitmap output.
test_bitmap_traversal () {
	if test "$1" = "--no-confirm-bitmaps"
	then
		shift
	elif cmp "$1" "$2"
	then
		echo >&2 "identical raw outputs; are you sure bitmaps were used?"
		return 1
	fi &&
	cut -d' ' -f1 "$1" | sort >"$1.normalized" &&
	sort "$2" >"$2.normalized" &&
	test_cmp "$1.normalized" "$2.normalized" &&
	rm -f "$1.normalized" "$2.normalized"
}

# To ensure the logic for "maximal commits" is exercised, make
# the repository a bit more complicated.
#
#    other                         second
#      *                             *
# (99 commits)                  (99 commits)
#      *                             *
#      |\                           /|
#      | * octo-other  octo-second * |
#      |/|\_________  ____________/|\|
#      | \          \/  __________/  |
#      |  | ________/\ /             |
#      *  |/          * merge-right  *
#      | _|__________/ \____________ |
#      |/ |                         \|
# (l1) *  * merge-left               * (r1)
#      | / \________________________ |
#      |/                           \|
# (l2) *                             * (r2)
#       \___________________________ |
#                                   \|
#                                    * (base)
#
# We only defecate bits down the first-parent history, which
# makes some of these commits unimportant!
#
# The important part for the maximal commit algorithm is how
# the bitmasks are extended. Assuming starting bit positions
# for second (bit 0) and other (bit 1), the bitmasks at the
# end should be:
#
#      second: 1       (maximal, selected)
#       other: 01      (maximal, selected)
#      (base): 11 (maximal)
#
# This complicated history was important for a previous
# version of the walk that guarantees never walking a
# commit multiple times. That goal might be important
# again, so preserve this complicated case. For now, this
# test will guarantee that the bitmaps are computed
# correctly, even with the repeat calculations.
setup_bitmap_history() {
	test_expect_success 'setup repo with moderate-sized history' '
		test_commit_bulk --id=file 10 &&
		shit branch -M second &&
		shit checkout -b other HEAD~5 &&
		test_commit_bulk --id=side 10 &&

		# add complicated history setup, including merges and
		# ambiguous merge-bases

		shit checkout -b merge-left other~2 &&
		shit merge second~2 -m "merge-left" &&

		shit checkout -b merge-right second~1 &&
		shit merge other~1 -m "merge-right" &&

		shit checkout -b octo-second second &&
		shit merge merge-left merge-right -m "octopus-second" &&

		shit checkout -b octo-other other &&
		shit merge merge-left merge-right -m "octopus-other" &&

		shit checkout other &&
		shit merge octo-other -m "poop octopus" &&

		shit checkout second &&
		shit merge octo-second -m "poop octopus" &&

		# Remove these branches so they are not selected
		# as bitmap tips
		shit branch -D merge-left &&
		shit branch -D merge-right &&
		shit branch -D octo-other &&
		shit branch -D octo-second &&

		# add padding to make these merges less interesting
		# and avoid having them selected for bitmaps
		test_commit_bulk --id=file 100 &&
		shit checkout other &&
		test_commit_bulk --id=side 100 &&
		shit checkout second &&

		bitmaptip=$(shit rev-parse second) &&
		blob=$(echo tagged-blob | shit hash-object -w --stdin) &&
		shit tag tagged-blob $blob
	'
}

rev_list_tests_head () {
	test_expect_success "counting commits via bitmap ($state, $branch)" '
		shit rev-list --count $branch >expect &&
		shit rev-list --use-bitmap-index --count $branch >actual &&
		test_cmp expect actual
	'

	test_expect_success "counting partial commits via bitmap ($state, $branch)" '
		shit rev-list --count $branch~5..$branch >expect &&
		shit rev-list --use-bitmap-index --count $branch~5..$branch >actual &&
		test_cmp expect actual
	'

	test_expect_success "counting commits with limit ($state, $branch)" '
		shit rev-list --count -n 1 $branch >expect &&
		shit rev-list --use-bitmap-index --count -n 1 $branch >actual &&
		test_cmp expect actual
	'

	test_expect_success "counting non-linear history ($state, $branch)" '
		shit rev-list --count other...second >expect &&
		shit rev-list --use-bitmap-index --count other...second >actual &&
		test_cmp expect actual
	'

	test_expect_success "counting commits with limiting ($state, $branch)" '
		shit rev-list --count $branch -- 1.t >expect &&
		shit rev-list --use-bitmap-index --count $branch -- 1.t >actual &&
		test_cmp expect actual
	'

	test_expect_success "counting objects via bitmap ($state, $branch)" '
		shit rev-list --count --objects $branch >expect &&
		shit rev-list --use-bitmap-index --count --objects $branch >actual &&
		test_cmp expect actual
	'

	test_expect_success "enumerate commits ($state, $branch)" '
		shit rev-list --use-bitmap-index $branch >actual &&
		shit rev-list $branch >expect &&
		test_bitmap_traversal --no-confirm-bitmaps expect actual
	'

	test_expect_success "enumerate --objects ($state, $branch)" '
		shit rev-list --objects --use-bitmap-index $branch >actual &&
		shit rev-list --objects $branch >expect &&
		test_bitmap_traversal expect actual
	'

	test_expect_success "bitmap --objects handles non-commit objects ($state, $branch)" '
		shit rev-list --objects --use-bitmap-index $branch tagged-blob >actual &&
		grep $blob actual
	'
}

rev_list_tests () {
	state=$1

	for branch in "second" "other"
	do
		rev_list_tests_head
	done
}

basic_bitmap_tests () {
	tip="$1"
	test_expect_success 'rev-list --test-bitmap verifies bitmaps' "
		shit rev-list --test-bitmap "${tip:-HEAD}"
	"

	rev_list_tests 'full bitmap'

	test_expect_success 'clone from bitmapped repository' '
		rm -fr clone.shit &&
		shit clone --no-local --bare . clone.shit &&
		shit rev-parse HEAD >expect &&
		shit --shit-dir=clone.shit rev-parse HEAD >actual &&
		test_cmp expect actual
	'

	test_expect_success 'partial clone from bitmapped repository' '
		test_config uploadpack.allowfilter true &&
		rm -fr partial-clone.shit &&
		shit clone --no-local --bare --filter=blob:none . partial-clone.shit &&
		(
			cd partial-clone.shit &&
			pack=$(echo objects/pack/*.pack) &&
			shit verify-pack -v "$pack" >have &&
			awk "/blob/ { print \$1 }" <have >blobs &&
			# we expect this single blob because of the direct ref
			shit rev-parse refs/tags/tagged-blob >expect &&
			test_cmp expect blobs
		)
	'

	test_expect_success 'setup further non-bitmapped commits' '
		test_commit_bulk --id=further 10
	'

	rev_list_tests 'partial bitmap'

	test_expect_success 'fetch (partial bitmap)' '
		shit --shit-dir=clone.shit fetch origin second:second &&
		shit rev-parse HEAD >expect &&
		shit --shit-dir=clone.shit rev-parse HEAD >actual &&
		test_cmp expect actual
	'

	test_expect_success 'enumerating progress counts pack-reused objects' '
		count=$(shit rev-list --objects --all --count) &&
		shit repack -adb &&

		# check first with only reused objects; confirm that our
		# progress showed the right number, and also that we did
		# pack-reuse as expected.  Check only the final "done"
		# line of the meter (there may be an arbitrary number of
		# intermediate lines ending with CR).
		shit_PROGRESS_DELAY=0 \
			shit pack-objects --all --stdout --progress \
			</dev/null >/dev/null 2>stderr &&
		grep "Enumerating objects: $count, done" stderr &&
		grep "pack-reused $count" stderr &&

		# now the same but with one non-reused object
		shit commit --allow-empty -m "an extra commit object" &&
		shit_PROGRESS_DELAY=0 \
			shit pack-objects --all --stdout --progress \
			</dev/null >/dev/null 2>stderr &&
		grep "Enumerating objects: $((count+1)), done" stderr &&
		grep "pack-reused $count" stderr
	'
}

# have_delta <obj> <expected_base>
#
# Note that because this relies on cat-file, it might find _any_ copy of an
# object in the repository. The caller is responsible for making sure
# there's only one (e.g., via "repack -ad", or having just fetched a copy).
have_delta () {
	echo $2 >expect &&
	echo $1 | shit cat-file --batch-check="%(deltabase)" >actual &&
	test_cmp expect actual
}

midx_checksum () {
	test-tool read-midx --checksum "$1"
}

# midx_pack_source <obj>
midx_pack_source () {
	test-tool read-midx --show-objects .shit/objects | grep "^$1 " | cut -f2
}

test_rev_exists () {
	commit="$1"
	kind="$2"

	test_expect_success "reverse index exists ($kind)" '
		shit_TRACE2_EVENT=$(pwd)/event.trace \
			shit rev-list --test-bitmap "$commit" &&

		if test "rev" = "$kind"
		then
			test_path_is_file $midx-$(midx_checksum $objdir).rev
		fi &&
		grep "\"category\":\"load_midx_revindex\",\"key\":\"source\",\"value\":\"$kind\"" event.trace
	'
}

midx_bitmap_core () {
	rev_kind="${1:-midx}"

	setup_bitmap_history

	test_expect_success 'create single-pack midx with bitmaps' '
		shit repack -ad &&
		shit multi-pack-index write --bitmap &&
		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap
	'

	test_rev_exists HEAD "$rev_kind"

	basic_bitmap_tests

	test_expect_success 'create new additional packs' '
		for i in $(test_seq 1 16)
		do
			test_commit "$i" &&
			shit repack -d || return 1
		done &&

		shit checkout -b other2 HEAD~8 &&
		for i in $(test_seq 1 8)
		do
			test_commit "side-$i" &&
			shit repack -d || return 1
		done &&
		shit checkout second
	'

	test_expect_success 'create multi-pack midx with bitmaps' '
		shit multi-pack-index write --bitmap &&

		ls $objdir/pack/pack-*.pack >packs &&
		test_line_count = 25 packs &&

		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap
	'

	test_rev_exists HEAD "$rev_kind"

	basic_bitmap_tests

	test_expect_success '--no-bitmap is respected when bitmaps exist' '
		shit multi-pack-index write --bitmap &&

		test_commit respect--no-bitmap &&
		shit repack -d &&

		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap &&

		shit multi-pack-index write --no-bitmap &&

		test_path_is_file $midx &&
		test_path_is_missing $midx-$(midx_checksum $objdir).bitmap &&
		test_path_is_missing $midx-$(midx_checksum $objdir).rev
	'

	test_expect_success 'setup midx with base from later pack' '
		# Write a and b so that "a" is a delta on top of base "b", since shit
		# prefers to delete contents out of a base rather than add to a shorter
		# object.
		test_seq 1 128 >a &&
		test_seq 1 130 >b &&

		shit add a b &&
		shit commit -m "initial commit" &&

		a=$(shit rev-parse HEAD:a) &&
		b=$(shit rev-parse HEAD:b) &&

		# In the first pack, "a" is stored as a delta to "b".
		p1=$(shit pack-objects .shit/objects/pack/pack <<-EOF
		$a
		$b
		EOF
		) &&

		# In the second pack, "a" is missing, and "b" is not a delta nor base to
		# any other object.
		p2=$(shit pack-objects .shit/objects/pack/pack <<-EOF
		$b
		$(shit rev-parse HEAD)
		$(shit rev-parse HEAD^{tree})
		EOF
		) &&

		shit prune-packed &&
		# Use the second pack as the preferred source, so that "b" occurs
		# earlier in the MIDX object order, rendering "a" unusable for pack
		# reuse.
		shit multi-pack-index write --bitmap --preferred-pack=pack-$p2.idx &&

		have_delta $a $b &&
		test $(midx_pack_source $a) != $(midx_pack_source $b)
	'

	rev_list_tests 'full bitmap with backwards delta'

	test_expect_success 'clone with bitmaps enabled' '
		shit clone --no-local --bare . clone-reverse-delta.shit &&
		test_when_finished "rm -fr clone-reverse-delta.shit" &&

		shit rev-parse HEAD >expect &&
		shit --shit-dir=clone-reverse-delta.shit rev-parse HEAD >actual &&
		test_cmp expect actual
	'

	test_expect_success 'changing the preferred pack does not corrupt bitmaps' '
		rm -fr repo &&
		shit init repo &&
		test_when_finished "rm -fr repo" &&
		(
			cd repo &&

			test_commit A &&
			test_commit B &&

			shit rev-list --objects --no-object-names HEAD^ >A.objects &&
			shit rev-list --objects --no-object-names HEAD^.. >B.objects &&

			A=$(shit pack-objects $objdir/pack/pack <A.objects) &&
			B=$(shit pack-objects $objdir/pack/pack <B.objects) &&

			cat >indexes <<-EOF &&
			pack-$A.idx
			pack-$B.idx
			EOF

			shit multi-pack-index write --bitmap --stdin-packs \
				--preferred-pack=pack-$A.pack <indexes &&
			shit rev-list --test-bitmap A &&

			shit multi-pack-index write --bitmap --stdin-packs \
				--preferred-pack=pack-$B.pack <indexes &&
			shit rev-list --test-bitmap A
		)
	'
}

midx_bitmap_partial_tests () {
	rev_kind="${1:-midx}"

	test_expect_success 'setup partial bitmaps' '
		test_commit packed &&
		shit repack &&
		test_commit loose &&
		shit multi-pack-index write --bitmap &&
		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap
	'

	test_rev_exists HEAD~ "$rev_kind"

	basic_bitmap_tests HEAD~
}
