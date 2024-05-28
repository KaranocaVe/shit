#!/bin/sh

test_description='shit repack works correctly'

. ./test-lib.sh
. "${TEST_DIRECTORY}/lib-bitmap.sh"
. "${TEST_DIRECTORY}/lib-midx.sh"
. "${TEST_DIRECTORY}/lib-terminal.sh"

commit_and_pack () {
	test_commit "$@" 1>&2 &&
	incrpackid=$(shit pack-objects --all --unpacked --incremental .shit/objects/pack/pack </dev/null) &&
	# Remove any loose object(s) created by test_commit, since they have
	# already been packed. Leaving these around can create subtly different
	# packs with `pack-objects`'s `--unpacked` option.
	shit prune-packed 1>&2 &&
	echo pack-${incrpackid}.pack
}

test_no_missing_in_packs () {
	myidx=$(ls -1 .shit/objects/pack/*.idx) &&
	test_path_is_file "$myidx" &&
	shit verify-pack -v alt_objects/pack/*.idx >orig.raw &&
	sed -n -e "s/^\($OID_REGEX\).*/\1/p" orig.raw | sort >orig &&
	shit verify-pack -v $myidx >dest.raw &&
	cut -d" " -f1 dest.raw | sort >dest &&
	comm -23 orig dest >missing &&
	test_must_be_empty missing
}

# we expect $packid and $oid to be defined
test_has_duplicate_object () {
	want_duplicate_object="$1"
	found_duplicate_object=false
	for p in .shit/objects/pack/*.idx
	do
		idx=$(basename $p)
		test "pack-$packid.idx" = "$idx" && continue
		shit verify-pack -v $p >packlist || return $?
		if grep "^$oid" packlist
		then
			found_duplicate_object=true
			echo "DUPLICATE OBJECT FOUND"
			break
		fi
	done &&
	test "$want_duplicate_object" = "$found_duplicate_object"
}

test_expect_success 'objects in packs marked .keep are not repacked' '
	echo content1 >file1 &&
	echo content2 >file2 &&
	shit add . &&
	test_tick &&
	shit commit -m initial_commit &&
	# Create two packs
	# The first pack will contain all of the objects except one
	shit rev-list --objects --all >objs &&
	grep -v file2 objs | shit pack-objects pack &&
	# The second pack will contain the excluded object
	packid=$(grep file2 objs | shit pack-objects pack) &&
	>pack-$packid.keep &&
	shit verify-pack -v pack-$packid.idx >packlist &&
	oid=$(head -n 1 packlist | sed -e "s/^\($OID_REGEX\).*/\1/") &&
	mv pack-* .shit/objects/pack/ &&
	shit repack -A -d -l &&
	shit prune-packed &&
	test_has_duplicate_object false
'

test_expect_success 'writing bitmaps via command-line can duplicate .keep objects' '
	# build on $oid, $packid, and .keep state from previous
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 shit repack -Adbl &&
	test_has_duplicate_object true
'

test_expect_success 'writing bitmaps via config can duplicate .keep objects' '
	# build on $oid, $packid, and .keep state from previous
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -c repack.writebitmaps=true repack -Adl &&
	test_has_duplicate_object true
'

test_expect_success 'loose objects in alternate ODB are not repacked' '
	mkdir alt_objects &&
	echo $(pwd)/alt_objects >.shit/objects/info/alternates &&
	echo content3 >file3 &&
	oid=$(shit_OBJECT_DIRECTORY=alt_objects shit hash-object -w file3) &&
	shit add file3 &&
	test_tick &&
	shit commit -m commit_file3 &&
	shit repack -a -d -l &&
	shit prune-packed &&
	test_has_duplicate_object false
'

test_expect_success SYMLINKS '--local keeps packs when alternate is objectdir ' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	test_commit -C repo A &&
	(
		cd repo &&
		shit repack -a &&
		ls .shit/objects/pack/*.pack >../expect &&
		ln -s objects .shit/alt_objects &&
		echo "$(pwd)/.shit/alt_objects" >.shit/objects/info/alternates &&
		shit repack -a -d -l &&
		ls .shit/objects/pack/*.pack >../actual
	) &&
	test_cmp expect actual
'

test_expect_success '--local disables writing bitmaps when connected to alternate ODB' '
	test_when_finished "rm -rf shared member" &&

	shit init shared &&
	shit clone --shared shared member &&
	(
		cd member &&
		test_commit "object" &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Adl --write-bitmap-index 2>err &&
		cat >expect <<-EOF &&
		warning: disabling bitmap writing, as some objects are not being packed
		EOF
		test_cmp expect err &&
		test_path_is_missing .shit/objects/pack-*.bitmap
	)
'

test_expect_success 'packed obs in alt ODB are repacked even when local repo is packless' '
	mkdir alt_objects/pack &&
	mv .shit/objects/pack/* alt_objects/pack &&
	shit repack -a &&
	test_no_missing_in_packs
'

test_expect_success 'packed obs in alt ODB are repacked when local repo has packs' '
	rm -f .shit/objects/pack/* &&
	echo new_content >>file1 &&
	shit add file1 &&
	test_tick &&
	shit commit -m more_content &&
	shit repack &&
	shit repack -a -d &&
	test_no_missing_in_packs
'

test_expect_success 'packed obs in alternate ODB kept pack are repacked' '
	# swap the .keep so the commit object is in the pack with .keep
	for p in alt_objects/pack/*.pack
	do
		base_name=$(basename $p .pack) &&
		if test_path_is_file alt_objects/pack/$base_name.keep
		then
			rm alt_objects/pack/$base_name.keep
		else
			touch alt_objects/pack/$base_name.keep
		fi || return 1
	done &&
	shit repack -a -d &&
	test_no_missing_in_packs
'

test_expect_success 'packed unreachable obs in alternate ODB are not loosened' '
	rm -f alt_objects/pack/*.keep &&
	mv .shit/objects/pack/* alt_objects/pack/ &&
	coid=$(shit rev-parse HEAD^{commit}) &&
	shit reset --hard HEAD^ &&
	test_tick &&
	shit reflog expire --expire=$test_tick --expire-unreachable=$test_tick --all &&
	# The pack-objects call on the next line is equivalent to
	# shit repack -A -d without the call to prune-packed
	shit pack-objects --honor-pack-keep --non-empty --all --reflog \
	    --unpack-unreachable </dev/null pack &&
	rm -f .shit/objects/pack/* &&
	mv pack-* .shit/objects/pack/ &&
	shit verify-pack -v -- .shit/objects/pack/*.idx >packlist &&
	! grep "^$coid " packlist &&
	echo >.shit/objects/info/alternates &&
	test_must_fail shit show $coid
'

test_expect_success 'local packed unreachable obs that exist in alternate ODB are not loosened' '
	echo $(pwd)/alt_objects >.shit/objects/info/alternates &&
	echo "$coid" | shit pack-objects --non-empty --all --reflog pack &&
	rm -f .shit/objects/pack/* &&
	mv pack-* .shit/objects/pack/ &&
	# The pack-objects call on the next line is equivalent to
	# shit repack -A -d without the call to prune-packed
	shit pack-objects --honor-pack-keep --non-empty --all --reflog \
	    --unpack-unreachable </dev/null pack &&
	rm -f .shit/objects/pack/* &&
	mv pack-* .shit/objects/pack/ &&
	shit verify-pack -v -- .shit/objects/pack/*.idx >packlist &&
	! grep "^$coid " &&
	echo >.shit/objects/info/alternates &&
	test_must_fail shit show $coid
'

test_expect_success 'objects made unreachable by grafts only are kept' '
	test_tick &&
	shit commit --allow-empty -m "commit 4" &&
	H0=$(shit rev-parse HEAD) &&
	H1=$(shit rev-parse HEAD^) &&
	H2=$(shit rev-parse HEAD^^) &&
	echo "$H0 $H2" >.shit/info/grafts &&
	shit reflog expire --expire=$test_tick --expire-unreachable=$test_tick --all &&
	shit repack -a -d &&
	shit cat-file -t $H1
'

test_expect_success 'repack --keep-pack' '
	test_create_repo keep-pack &&
	(
		cd keep-pack &&
		# avoid producing different packs due to delta/base choices
		shit config pack.window 0 &&
		P1=$(commit_and_pack 1) &&
		P2=$(commit_and_pack 2) &&
		P3=$(commit_and_pack 3) &&
		P4=$(commit_and_pack 4) &&
		ls .shit/objects/pack/*.pack >old-counts &&
		test_line_count = 4 old-counts &&
		shit repack -a -d --keep-pack $P1 --keep-pack $P4 &&
		ls .shit/objects/pack/*.pack >new-counts &&
		grep -q $P1 new-counts &&
		grep -q $P4 new-counts &&
		test_line_count = 3 new-counts &&
		shit fsck &&

		P5=$(commit_and_pack --no-tag 5) &&
		shit reset --hard HEAD^ &&
		shit reflog expire --all --expire=all &&
		rm -f ".shit/objects/pack/${P5%.pack}.idx" &&
		rm -f ".shit/objects/info/commit-graph" &&
		for from in $(find .shit/objects/pack -type f -name "${P5%.pack}.*")
		do
			to="$(dirname "$from")/.tmp-1234-$(basename "$from")" &&
			mv "$from" "$to" || return 1
		done &&

		# A .idx file without a .pack should not stop us from
		# repacking what we can.
		touch .shit/objects/pack/pack-does-not-exist.idx &&

		shit repack --cruft -d --keep-pack $P1 --keep-pack $P4 &&

		ls .shit/objects/pack/*.pack >newer-counts &&
		test_cmp new-counts newer-counts &&
		shit fsck
	)
'

test_expect_success 'repacking fails when missing .pack actually means missing objects' '
	test_create_repo idx-without-pack &&
	(
		cd idx-without-pack &&

		# Avoid producing different packs due to delta/base choices
		shit config pack.window 0 &&
		P1=$(commit_and_pack 1) &&
		P2=$(commit_and_pack 2) &&
		P3=$(commit_and_pack 3) &&
		P4=$(commit_and_pack 4) &&
		ls .shit/objects/pack/*.pack >old-counts &&
		test_line_count = 4 old-counts &&

		# Remove one .pack file
		rm .shit/objects/pack/$P2 &&

		ls .shit/objects/pack/*.pack >before-pack-dir &&

		test_must_fail shit fsck &&
		test_must_fail env shit_COMMIT_GRAPH_PARANOIA=true shit repack --cruft -d 2>err &&
		grep "bad object" err &&

		# Before failing, the repack did not modify the
		# pack directory.
		ls .shit/objects/pack/*.pack >after-pack-dir &&
		test_cmp before-pack-dir after-pack-dir
	)
'

test_expect_success 'bitmaps are created by default in bare repos' '
	shit clone --bare .shit bare.shit &&
	rm -f bare.shit/objects/pack/*.bitmap &&
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -C bare.shit repack -ad &&
	bitmap=$(ls bare.shit/objects/pack/*.bitmap) &&
	test_path_is_file "$bitmap"
'

test_expect_success 'incremental repack does not complain' '
	shit -C bare.shit repack -q 2>repack.err &&
	test_must_be_empty repack.err
'

test_expect_success 'bitmaps can be disabled on bare repos' '
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -c repack.writeBitmaps=false -C bare.shit repack -ad &&
	bitmap=$(ls bare.shit/objects/pack/*.bitmap || :) &&
	test -z "$bitmap"
'

test_expect_success 'no bitmaps created if .keep files present' '
	pack=$(ls bare.shit/objects/pack/*.pack) &&
	test_path_is_file "$pack" &&
	keep=${pack%.pack}.keep &&
	test_when_finished "rm -f \"\$keep\"" &&
	>"$keep" &&
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -C bare.shit repack -ad 2>stderr &&
	test_must_be_empty stderr &&
	find bare.shit/objects/pack/ -type f -name "*.bitmap" >actual &&
	test_must_be_empty actual
'

test_expect_success 'auto-bitmaps do not complain if unavailable' '
	test_config -C bare.shit pack.packSizeLimit 1M &&
	blob=$(test-tool genrandom big $((1024*1024)) |
	       shit -C bare.shit hash-object -w --stdin) &&
	shit -C bare.shit update-ref refs/tags/big $blob &&
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -C bare.shit repack -ad 2>stderr &&
	test_must_be_empty stderr &&
	find bare.shit/objects/pack -type f -name "*.bitmap" >actual &&
	test_must_be_empty actual
'

test_expect_success 'repacking with a filter works' '
	shit -C bare.shit repack -a -d &&
	test_stdout_line_count = 1 ls bare.shit/objects/pack/*.pack &&
	shit -C bare.shit -c repack.writebitmaps=false repack -a -d --filter=blob:none &&
	test_stdout_line_count = 2 ls bare.shit/objects/pack/*.pack &&
	commit_pack=$(test-tool -C bare.shit find-pack -c 1 HEAD) &&
	blob_pack=$(test-tool -C bare.shit find-pack -c 1 HEAD:file1) &&
	test "$commit_pack" != "$blob_pack" &&
	tree_pack=$(test-tool -C bare.shit find-pack -c 1 HEAD^{tree}) &&
	test "$tree_pack" = "$commit_pack" &&
	blob_pack2=$(test-tool -C bare.shit find-pack -c 1 HEAD:file2) &&
	test "$blob_pack2" = "$blob_pack"
'

test_expect_success '--filter fails with --write-bitmap-index' '
	test_must_fail \
		env shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -C bare.shit repack -a -d --write-bitmap-index --filter=blob:none
'

test_expect_success 'repacking with two filters works' '
	shit init two-filters &&
	(
		cd two-filters &&
		mkdir subdir &&
		test_commit foo &&
		test_commit subdir_bar subdir/bar &&
		test_commit subdir_baz subdir/baz
	) &&
	shit clone --no-local --bare two-filters two-filters.shit &&
	(
		cd two-filters.shit &&
		test_stdout_line_count = 1 ls objects/pack/*.pack &&
		shit -c repack.writebitmaps=false repack -a -d \
			--filter=blob:none --filter=tree:1 &&
		test_stdout_line_count = 2 ls objects/pack/*.pack &&
		commit_pack=$(test-tool find-pack -c 1 HEAD) &&
		blob_pack=$(test-tool find-pack -c 1 HEAD:foo.t) &&
		root_tree_pack=$(test-tool find-pack -c 1 HEAD^{tree}) &&
		subdir_tree_hash=$(shit ls-tree --object-only HEAD -- subdir) &&
		subdir_tree_pack=$(test-tool find-pack -c 1 "$subdir_tree_hash") &&

		# Root tree and subdir tree are not in the same packfiles
		test "$commit_pack" != "$blob_pack" &&
		test "$commit_pack" = "$root_tree_pack" &&
		test "$blob_pack" = "$subdir_tree_pack"
	)
'

prepare_for_keep_packs () {
	shit init keep-packs &&
	(
		cd keep-packs &&
		test_commit foo &&
		test_commit bar
	) &&
	shit clone --no-local --bare keep-packs keep-packs.shit &&
	(
		cd keep-packs.shit &&

		# Create two packs
		# The first pack will contain all of the objects except one blob
		shit rev-list --objects --all >objs &&
		grep -v "bar.t" objs | shit pack-objects pack &&
		# The second pack will contain the excluded object and be kept
		packid=$(grep "bar.t" objs | shit pack-objects pack) &&
		>pack-$packid.keep &&

		# Replace the existing pack with the 2 new ones
		rm -f objects/pack/pack* &&
		mv pack-* objects/pack/
	)
}

test_expect_success '--filter works with .keep packs' '
	prepare_for_keep_packs &&
	(
		cd keep-packs.shit &&

		foo_pack=$(test-tool find-pack -c 1 HEAD:foo.t) &&
		bar_pack=$(test-tool find-pack -c 1 HEAD:bar.t) &&
		head_pack=$(test-tool find-pack -c 1 HEAD) &&

		test "$foo_pack" != "$bar_pack" &&
		test "$foo_pack" = "$head_pack" &&

		shit -c repack.writebitmaps=false repack -a -d --filter=blob:none &&

		foo_pack_1=$(test-tool find-pack -c 1 HEAD:foo.t) &&
		bar_pack_1=$(test-tool find-pack -c 1 HEAD:bar.t) &&
		head_pack_1=$(test-tool find-pack -c 1 HEAD) &&

		# Object bar is still only in the old .keep pack
		test "$foo_pack_1" != "$foo_pack" &&
		test "$bar_pack_1" = "$bar_pack" &&
		test "$head_pack_1" != "$head_pack" &&

		test "$foo_pack_1" != "$bar_pack_1" &&
		test "$foo_pack_1" != "$head_pack_1" &&
		test "$bar_pack_1" != "$head_pack_1"
	)
'

test_expect_success '--filter works with --pack-kept-objects and .keep packs' '
	rm -rf keep-packs keep-packs.shit &&
	prepare_for_keep_packs &&
	(
		cd keep-packs.shit &&

		foo_pack=$(test-tool find-pack -c 1 HEAD:foo.t) &&
		bar_pack=$(test-tool find-pack -c 1 HEAD:bar.t) &&
		head_pack=$(test-tool find-pack -c 1 HEAD) &&

		test "$foo_pack" != "$bar_pack" &&
		test "$foo_pack" = "$head_pack" &&

		shit -c repack.writebitmaps=false repack -a -d --filter=blob:none \
			--pack-kept-objects &&

		foo_pack_1=$(test-tool find-pack -c 1 HEAD:foo.t) &&
		test-tool find-pack -c 2 HEAD:bar.t >bar_pack_1 &&
		head_pack_1=$(test-tool find-pack -c 1 HEAD) &&

		test "$foo_pack_1" != "$foo_pack" &&
		test "$foo_pack_1" != "$bar_pack" &&
		test "$head_pack_1" != "$head_pack" &&

		# Object bar is in both the old .keep pack and the new
		# pack that contained the filtered out objects
		grep "$bar_pack" bar_pack_1 &&
		grep "$foo_pack_1" bar_pack_1 &&
		test "$foo_pack_1" != "$head_pack_1"
	)
'

test_expect_success '--filter-to stores filtered out objects' '
	shit -C bare.shit repack -a -d &&
	test_stdout_line_count = 1 ls bare.shit/objects/pack/*.pack &&

	shit init --bare filtered.shit &&
	shit -C bare.shit -c repack.writebitmaps=false repack -a -d \
		--filter=blob:none \
		--filter-to=../filtered.shit/objects/pack/pack &&
	test_stdout_line_count = 1 ls bare.shit/objects/pack/pack-*.pack &&
	test_stdout_line_count = 1 ls filtered.shit/objects/pack/pack-*.pack &&

	commit_pack=$(test-tool -C bare.shit find-pack -c 1 HEAD) &&
	blob_pack=$(test-tool -C bare.shit find-pack -c 0 HEAD:file1) &&
	blob_hash=$(shit -C bare.shit rev-parse HEAD:file1) &&
	test -n "$blob_hash" &&
	blob_pack=$(test-tool -C filtered.shit find-pack -c 1 $blob_hash) &&

	echo $(pwd)/filtered.shit/objects >bare.shit/objects/info/alternates &&
	blob_pack=$(test-tool -C bare.shit find-pack -c 1 HEAD:file1) &&
	blob_content=$(shit -C bare.shit show $blob_hash) &&
	test "$blob_content" = "content1"
'

test_expect_success '--filter works with --max-pack-size' '
	rm -rf filtered.shit &&
	shit init --bare filtered.shit &&
	shit init max-pack-size &&
	(
		cd max-pack-size &&
		test_commit base &&
		# two blobs which exceed the maximum pack size
		test-tool genrandom foo 1048576 >foo &&
		shit hash-object -w foo &&
		test-tool genrandom bar 1048576 >bar &&
		shit hash-object -w bar &&
		shit add foo bar &&
		shit commit -m "adding foo and bar"
	) &&
	shit clone --no-local --bare max-pack-size max-pack-size.shit &&
	(
		cd max-pack-size.shit &&
		shit -c repack.writebitmaps=false repack -a -d --filter=blob:none \
			--max-pack-size=1M \
			--filter-to=../filtered.shit/objects/pack/pack &&
		echo $(cd .. && pwd)/filtered.shit/objects >objects/info/alternates &&

		# Check that the 3 blobs are in different packfiles in filtered.shit
		test_stdout_line_count = 3 ls ../filtered.shit/objects/pack/pack-*.pack &&
		test_stdout_line_count = 1 ls objects/pack/pack-*.pack &&
		foo_pack=$(test-tool find-pack -c 1 HEAD:foo) &&
		bar_pack=$(test-tool find-pack -c 1 HEAD:bar) &&
		base_pack=$(test-tool find-pack -c 1 HEAD:base.t) &&
		test "$foo_pack" != "$bar_pack" &&
		test "$foo_pack" != "$base_pack" &&
		test "$bar_pack" != "$base_pack" &&
		for pack in "$foo_pack" "$bar_pack" "$base_pack"
		do
			case "$foo_pack" in */filtered.shit/objects/pack/*) true ;; *) return 1 ;; esac
		done
	)
'

objdir=.shit/objects
midx=$objdir/pack/multi-pack-index

test_expect_success 'setup for --write-midx tests' '
	shit init midx &&
	(
		cd midx &&
		shit config core.multiPackIndex true &&

		test_commit base
	)
'

test_expect_success '--write-midx unchanged' '
	(
		cd midx &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack &&
		test_path_is_missing $midx &&
		test_path_is_missing $midx-*.bitmap &&

		shit_TEST_MULTI_PACK_INDEX=0 shit repack --write-midx &&

		test_path_is_file $midx &&
		test_path_is_missing $midx-*.bitmap &&
		test_midx_consistent $objdir
	)
'

test_expect_success '--write-midx with a new pack' '
	(
		cd midx &&
		test_commit loose &&

		shit_TEST_MULTI_PACK_INDEX=0 shit repack --write-midx &&

		test_path_is_file $midx &&
		test_path_is_missing $midx-*.bitmap &&
		test_midx_consistent $objdir
	)
'

test_expect_success '--write-midx with -b' '
	(
		cd midx &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -mb &&

		test_path_is_file $midx &&
		test_path_is_file $midx-*.bitmap &&
		test_midx_consistent $objdir
	)
'

test_expect_success '--write-midx with -d' '
	(
		cd midx &&
		test_commit repack &&

		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Ad --write-midx &&

		test_path_is_file $midx &&
		test_path_is_missing $midx-*.bitmap &&
		test_midx_consistent $objdir
	)
'

test_expect_success 'cleans up MIDX when appropriate' '
	(
		cd midx &&

		test_commit repack-2 &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Adb --write-midx &&

		checksum=$(midx_checksum $objdir) &&
		test_path_is_file $midx &&
		test_path_is_file $midx-$checksum.bitmap &&

		test_commit repack-3 &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Adb --write-midx &&

		test_path_is_file $midx &&
		test_path_is_missing $midx-$checksum.bitmap &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap &&

		test_commit repack-4 &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Adb &&

		find $objdir/pack -type f -name "multi-pack-index*" >files &&
		test_must_be_empty files
	)
'

test_expect_success '--write-midx with preferred bitmap tips' '
	shit init midx-preferred-tips &&
	test_when_finished "rm -fr midx-preferred-tips" &&
	(
		cd midx-preferred-tips &&

		test_commit_bulk --message="%s" 103 &&

		shit log --format="%H" >commits.raw &&
		sort <commits.raw >commits &&

		shit log --format="create refs/tags/%s/%s %H" HEAD >refs &&
		shit update-ref --stdin <refs &&

		shit_TEST_MULTI_PACK_INDEX=0 \
		shit repack --write-midx --write-bitmap-index &&
		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap &&

		test-tool bitmap list-commits | sort >bitmaps &&
		comm -13 bitmaps commits >before &&
		test_line_count = 1 before &&

		rm -fr $midx-$(midx_checksum $objdir).bitmap &&
		rm -fr $midx &&

		# instead of constructing the snapshot ourselves (c.f., the test
		# "write a bitmap with --refs-snapshot (preferred tips)" in
		# t5326), mark the missing commit as preferred by adding it to
		# the pack.preferBitmapTips configuration.
		shit for-each-ref --format="%(refname:rstrip=1)" \
			--points-at="$(cat before)" >missing &&
		shit config pack.preferBitmapTips "$(cat missing)" &&
		shit repack --write-midx --write-bitmap-index &&

		test-tool bitmap list-commits | sort >bitmaps &&
		comm -13 bitmaps commits >after &&

		! test_cmp before after
	)
'

# The first argument is expected to be a filename
# and that file should contain the name of a .idx
# file. Send the list of objects in that .idx file
# into stdout.
get_sorted_objects_from_pack () {
	shit show-index <$(cat "$1") >raw &&
	cut -d" " -f2 raw
}

test_expect_success '--write-midx -b packs non-kept objects' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		# Create a kept pack-file
		test_commit base &&
		shit repack -ad &&
		find $objdir/pack -name "*.idx" >before &&
		test_line_count = 1 before &&
		before_name=$(cat before) &&
		>${before_name%.idx}.keep &&

		# Create a non-kept pack-file
		test_commit other &&
		shit repack &&

		# Create loose objects
		test_commit loose &&

		# Repack everything
		shit repack --write-midx -a -b -d &&

		# There should be two pack-files now, the
		# old, kept pack and the new, non-kept pack.
		find $objdir/pack -name "*.idx" | sort >after &&
		test_line_count = 2 after &&
		find $objdir/pack -name "*.keep" >kept &&
		kept_name=$(cat kept) &&
		echo ${kept_name%.keep}.idx >kept-idx &&
		test_cmp before kept-idx &&

		# Get object list from the kept pack.
		get_sorted_objects_from_pack before >old.objects &&

		# Get object list from the one non-kept pack-file
		comm -13 before after >new-pack &&
		test_line_count = 1 new-pack &&
		get_sorted_objects_from_pack new-pack >new.objects &&

		# None of the objects in the new pack should
		# exist within the kept pack.
		comm -12 old.objects new.objects >shared.objects &&
		test_must_be_empty shared.objects
	)
'

test_expect_success '--write-midx removes stale pack-based bitmaps' '
	rm -fr repo &&
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&
		test_commit base &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -Ab &&

		pack_bitmap=$(ls $objdir/pack/pack-*.bitmap) &&
		test_path_is_file "$pack_bitmap" &&

		test_commit tip &&
		shit_TEST_MULTI_PACK_INDEX=0 shit repack -bm &&

		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap &&
		test_path_is_missing $pack_bitmap
	)
'

test_expect_success '--write-midx with --pack-kept-objects' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		test_commit one &&
		test_commit two &&

		one="$(echo "one" | shit pack-objects --revs $objdir/pack/pack)" &&
		two="$(echo "one..two" | shit pack-objects --revs $objdir/pack/pack)" &&

		keep="$objdir/pack/pack-$one.keep" &&
		touch "$keep" &&

		shit_TEST_MULTI_PACK_INDEX=0 \
		shit repack --write-midx --write-bitmap-index --geometric=2 -d \
			--pack-kept-objects &&

		test_path_is_file $keep &&
		test_path_is_file $midx &&
		test_path_is_file $midx-$(midx_checksum $objdir).bitmap
	)
'

test_expect_success TTY '--quiet disables progress' '
	test_terminal env shit_PROGRESS_DELAY=0 \
		shit -C midx repack -ad --quiet --write-midx 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'clean up .tmp-* packs on error' '
	test_must_fail ok=sigpipe shit \
		-c repack.cruftwindow=bogus \
		repack -ad --cruft &&
	find $objdir/pack -name '.tmp-*' >tmpfiles &&
	test_must_be_empty tmpfiles
'

test_expect_success 'repack -ad cleans up old .tmp-* packs' '
	shit rev-parse HEAD >input &&
	shit pack-objects $objdir/pack/.tmp-1234 <input &&
	shit repack -ad &&
	find $objdir/pack -name '.tmp-*' >tmpfiles &&
	test_must_be_empty tmpfiles
'

test_expect_success 'setup for update-server-info' '
	shit init update-server-info &&
	test_commit -C update-server-info message
'

test_server_info_present () {
	test_path_is_file update-server-info/.shit/objects/info/packs &&
	test_path_is_file update-server-info/.shit/info/refs
}

test_server_info_missing () {
	test_path_is_missing update-server-info/.shit/objects/info/packs &&
	test_path_is_missing update-server-info/.shit/info/refs
}

test_server_info_cleanup () {
	rm -f update-server-info/.shit/objects/info/packs update-server-info/.shit/info/refs &&
	test_server_info_missing
}

test_expect_success 'updates server info by default' '
	test_server_info_cleanup &&
	shit -C update-server-info repack &&
	test_server_info_present
'

test_expect_success '-n skips updating server info' '
	test_server_info_cleanup &&
	shit -C update-server-info repack -n &&
	test_server_info_missing
'

test_expect_success 'repack.updateServerInfo=true updates server info' '
	test_server_info_cleanup &&
	shit -C update-server-info -c repack.updateServerInfo=true repack &&
	test_server_info_present
'

test_expect_success 'repack.updateServerInfo=false skips updating server info' '
	test_server_info_cleanup &&
	shit -C update-server-info -c repack.updateServerInfo=false repack &&
	test_server_info_missing
'

test_expect_success '-n overrides repack.updateServerInfo=true' '
	test_server_info_cleanup &&
	shit -C update-server-info -c repack.updateServerInfo=true repack -n &&
	test_server_info_missing
'

test_done
