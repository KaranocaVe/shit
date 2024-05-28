#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit pack-object

'
. ./test-lib.sh

test_expect_success 'setup' '
	rm -f .shit/index* &&
	perl -e "print \"a\" x 4096;" >a &&
	perl -e "print \"b\" x 4096;" >b &&
	perl -e "print \"c\" x 4096;" >c &&
	test-tool genrandom "seed a" 2097152 >a_big &&
	test-tool genrandom "seed b" 2097152 >b_big &&
	shit update-index --add a a_big b b_big c &&
	cat c >d && echo foo >>d && shit update-index --add d &&
	tree=$(shit write-tree) &&
	commit=$(shit commit-tree $tree </dev/null) &&
	{
		echo $tree &&
		echo $commit &&
		shit ls-tree $tree | sed -e "s/.* \\([0-9a-f]*\\)	.*/\\1/"
	} >obj-list &&
	{
		shit diff-tree --root -p $commit &&
		while read object
		do
			t=$(shit cat-file -t $object) &&
			shit cat-file $t $object || return 1
		done <obj-list
	} >expect
'

test_expect_success 'setup pack-object <stdin' '
	shit init pack-object-stdin &&
	test_commit -C pack-object-stdin one &&
	test_commit -C pack-object-stdin two

'

test_expect_success 'pack-object <stdin parsing: basic [|--revs]' '
	cat >in <<-EOF &&
	$(shit -C pack-object-stdin rev-parse one)
	EOF

	shit -C pack-object-stdin pack-objects basic-stdin <in &&
	idx=$(echo pack-object-stdin/basic-stdin-*.idx) &&
	shit show-index <"$idx" >actual &&
	test_line_count = 1 actual &&

	shit -C pack-object-stdin pack-objects --revs basic-stdin-revs <in &&
	idx=$(echo pack-object-stdin/basic-stdin-revs-*.idx) &&
	shit show-index <"$idx" >actual &&
	test_line_count = 3 actual
'

test_expect_success 'pack-object <stdin parsing: [|--revs] bad line' '
	cat >in <<-EOF &&
	$(shit -C pack-object-stdin rev-parse one)
	garbage
	$(shit -C pack-object-stdin rev-parse two)
	EOF

	sed "s/^> //g" >err.expect <<-EOF &&
	fatal: expected object ID, got garbage:
	>  garbage

	EOF
	test_must_fail shit -C pack-object-stdin pack-objects bad-line-stdin <in 2>err.actual &&
	test_cmp err.expect err.actual &&

	cat >err.expect <<-EOF &&
	fatal: bad revision '"'"'garbage'"'"'
	EOF
	test_must_fail shit -C pack-object-stdin pack-objects --revs bad-line-stdin-revs <in 2>err.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'pack-object <stdin parsing: [|--revs] empty line' '
	cat >in <<-EOF &&
	$(shit -C pack-object-stdin rev-parse one)

	$(shit -C pack-object-stdin rev-parse two)
	EOF

	sed -e "s/^> //g" -e "s/Z$//g" >err.expect <<-EOF &&
	fatal: expected object ID, got garbage:
	>  Z

	EOF
	test_must_fail shit -C pack-object-stdin pack-objects empty-line-stdin <in 2>err.actual &&
	test_cmp err.expect err.actual &&

	shit -C pack-object-stdin pack-objects --revs empty-line-stdin-revs <in &&
	idx=$(echo pack-object-stdin/empty-line-stdin-revs-*.idx) &&
	shit show-index <"$idx" >actual &&
	test_line_count = 3 actual
'

test_expect_success 'pack-object <stdin parsing: [|--revs] with --stdin' '
	cat >in <<-EOF &&
	$(shit -C pack-object-stdin rev-parse one)
	$(shit -C pack-object-stdin rev-parse two)
	EOF

	# There is the "--stdin-packs is incompatible with --revs"
	# test below, but we should make sure that the revision.c
	# --stdin is not picked up
	cat >err.expect <<-EOF &&
	fatal: disallowed abbreviated or ambiguous option '"'"'stdin'"'"'
	EOF
	test_must_fail shit -C pack-object-stdin pack-objects stdin-with-stdin-option --stdin <in 2>err.actual &&
	test_cmp err.expect err.actual &&

	test_must_fail shit -C pack-object-stdin pack-objects --stdin --revs stdin-with-stdin-option-revs 2>err.actual <in &&
	test_cmp err.expect err.actual
'

test_expect_success 'pack-object <stdin parsing: --stdin-packs handles garbage' '
	cat >in <<-EOF &&
	$(shit -C pack-object-stdin rev-parse one)
	$(shit -C pack-object-stdin rev-parse two)
	EOF

	# That we get "two" and not "one" has to do with OID
	# ordering. It happens to be the same here under SHA-1 and
	# SHA-256. See commentary in pack-objects.c
	cat >err.expect <<-EOF &&
	fatal: could not find pack '"'"'$(shit -C pack-object-stdin rev-parse two)'"'"'
	EOF
	test_must_fail shit \
		-C pack-object-stdin \
		pack-objects stdin-with-stdin-option --stdin-packs \
		<in 2>err.actual &&
	test_cmp err.expect err.actual
'

# usage: check_deltas <stderr_from_pack_objects> <cmp_op> <nr_deltas>
# e.g.: check_deltas stderr -gt 0
check_deltas() {
	deltas=$(perl -lne '/delta (\d+)/ and print $1' "$1") &&
	shift &&
	if ! test "$deltas" "$@"
	then
		echo >&2 "unexpected number of deltas (compared $delta $*)"
		return 1
	fi
}

test_expect_success 'pack without delta' '
	packname_1=$(shit pack-objects --progress --window=0 test-1 \
			<obj-list 2>stderr) &&
	check_deltas stderr = 0
'

test_expect_success 'pack-objects with bogus arguments' '
	test_must_fail shit pack-objects --window=0 test-1 blah blah <obj-list
'

check_unpack () {
	local packname="$1" &&
	local object_list="$2" &&
	local shit_config="$3" &&
	test_when_finished "rm -rf shit2" &&
	shit $shit_config init --bare shit2 &&
	(
		shit $shit_config -C shit2 unpack-objects -n <"$packname".pack &&
		shit $shit_config -C shit2 unpack-objects <"$packname".pack &&
		shit $shit_config -C shit2 cat-file --batch-check="%(objectname)"
	) <"$object_list" >current &&
	cmp "$object_list" current
}

test_expect_success 'unpack without delta' '
	check_unpack test-1-${packname_1} obj-list
'

BATCH_CONFIGURATION='-c core.fsync=loose-object -c core.fsyncmethod=batch'

test_expect_success 'unpack without delta (core.fsyncmethod=batch)' '
	check_unpack test-1-${packname_1} obj-list "$BATCH_CONFIGURATION"
'

test_expect_success 'pack with REF_DELTA' '
	packname_2=$(shit pack-objects --progress test-2 <obj-list 2>stderr) &&
	check_deltas stderr -gt 0
'

test_expect_success 'unpack with REF_DELTA' '
	check_unpack test-2-${packname_2} obj-list
'

test_expect_success 'unpack with REF_DELTA (core.fsyncmethod=batch)' '
       check_unpack test-2-${packname_2} obj-list "$BATCH_CONFIGURATION"
'

test_expect_success 'pack with OFS_DELTA' '
	packname_3=$(shit pack-objects --progress --delta-base-offset test-3 \
			<obj-list 2>stderr) &&
	check_deltas stderr -gt 0
'

test_expect_success 'unpack with OFS_DELTA' '
	check_unpack test-3-${packname_3} obj-list
'

test_expect_success 'unpack with OFS_DELTA (core.fsyncmethod=batch)' '
	check_unpack test-3-${packname_3} obj-list "$BATCH_CONFIGURATION"
'

test_expect_success 'compare delta flavors' '
	perl -e '\''
		defined($_ = -s $_) or die for @ARGV;
		exit 1 if $ARGV[0] <= $ARGV[1];
	'\'' test-2-$packname_2.pack test-3-$packname_3.pack
'

check_use_objects () {
	test_when_finished "rm -rf shit2" &&
	shit init --bare shit2 &&
	cp "$1".pack "$1".idx shit2/objects/pack &&
	(
		cd shit2 &&
		shit diff-tree --root -p $commit &&
		while read object
		do
			t=$(shit cat-file -t $object) &&
			shit cat-file $t $object || exit 1
		done
	) <obj-list >current &&
	cmp expect current
}

test_expect_success 'use packed objects' '
	check_use_objects test-1-${packname_1}
'

test_expect_success 'use packed deltified (REF_DELTA) objects' '
	check_use_objects test-2-${packname_2}
'

test_expect_success 'use packed deltified (OFS_DELTA) objects' '
	check_use_objects test-3-${packname_3}
'

test_expect_success 'survive missing objects/pack directory' '
	(
		rm -fr missing-pack &&
		mkdir missing-pack &&
		cd missing-pack &&
		shit init &&
		GOP=.shit/objects/pack &&
		rm -fr $GOP &&
		shit index-pack --stdin --keep=test <../test-3-${packname_3}.pack &&
		test -f $GOP/pack-${packname_3}.pack &&
		cmp $GOP/pack-${packname_3}.pack ../test-3-${packname_3}.pack &&
		test -f $GOP/pack-${packname_3}.idx &&
		cmp $GOP/pack-${packname_3}.idx ../test-3-${packname_3}.idx &&
		test -f $GOP/pack-${packname_3}.keep
	)
'

test_expect_success 'verify pack' '
	shit verify-pack test-1-${packname_1}.idx \
		test-2-${packname_2}.idx \
		test-3-${packname_3}.idx
'

test_expect_success 'verify pack -v' '
	shit verify-pack -v test-1-${packname_1}.idx \
		test-2-${packname_2}.idx \
		test-3-${packname_3}.idx
'

test_expect_success 'verify-pack catches mismatched .idx and .pack files' '
	cat test-1-${packname_1}.idx >test-3.idx &&
	cat test-2-${packname_2}.pack >test-3.pack &&
	if shit verify-pack test-3.idx
	then false
	else :;
	fi
'

test_expect_success 'verify-pack catches a corrupted pack signature' '
	cat test-1-${packname_1}.pack >test-3.pack &&
	echo | dd of=test-3.pack count=1 bs=1 conv=notrunc seek=2 &&
	if shit verify-pack test-3.idx
	then false
	else :;
	fi
'

test_expect_success 'verify-pack catches a corrupted pack version' '
	cat test-1-${packname_1}.pack >test-3.pack &&
	echo | dd of=test-3.pack count=1 bs=1 conv=notrunc seek=7 &&
	if shit verify-pack test-3.idx
	then false
	else :;
	fi
'

test_expect_success 'verify-pack catches a corrupted type/size of the 1st packed object data' '
	cat test-1-${packname_1}.pack >test-3.pack &&
	echo | dd of=test-3.pack count=1 bs=1 conv=notrunc seek=12 &&
	if shit verify-pack test-3.idx
	then false
	else :;
	fi
'

test_expect_success 'verify-pack catches a corrupted sum of the index file itself' '
	l=$(wc -c <test-3.idx) &&
	l=$(expr $l - 20) &&
	cat test-1-${packname_1}.pack >test-3.pack &&
	printf "%20s" "" | dd of=test-3.idx count=20 bs=1 conv=notrunc seek=$l &&
	if shit verify-pack test-3.pack
	then false
	else :;
	fi
'

test_expect_success 'build pack index for an existing pack' '
	cat test-1-${packname_1}.pack >test-3.pack &&
	shit index-pack -o tmp.idx test-3.pack &&
	cmp tmp.idx test-1-${packname_1}.idx &&

	shit index-pack --promisor=message test-3.pack &&
	cmp test-3.idx test-1-${packname_1}.idx &&
	echo message >expect &&
	test_cmp expect test-3.promisor &&

	cat test-2-${packname_2}.pack >test-3.pack &&
	shit index-pack -o tmp.idx test-2-${packname_2}.pack &&
	cmp tmp.idx test-2-${packname_2}.idx &&

	shit index-pack test-3.pack &&
	cmp test-3.idx test-2-${packname_2}.idx &&

	cat test-3-${packname_3}.pack >test-3.pack &&
	shit index-pack -o tmp.idx test-3-${packname_3}.pack &&
	cmp tmp.idx test-3-${packname_3}.idx &&

	shit index-pack test-3.pack &&
	cmp test-3.idx test-3-${packname_3}.idx &&

	cat test-1-${packname_1}.pack >test-4.pack &&
	rm -f test-4.keep &&
	shit index-pack --keep=why test-4.pack &&
	cmp test-1-${packname_1}.idx test-4.idx &&
	test -f test-4.keep &&

	:
'

test_expect_success 'unpacking with --strict' '

	for j in a b c d e f g
	do
		for i in 0 1 2 3 4 5 6 7 8 9
		do
			o=$(echo $j$i | shit hash-object -w --stdin) &&
			echo "100644 $o	0 $j$i" || return 1
		done
	done >LIST &&
	rm -f .shit/index &&
	shit update-index --index-info <LIST &&
	LIST=$(shit write-tree) &&
	rm -f .shit/index &&
	head -n 10 LIST | shit update-index --index-info &&
	LI=$(shit write-tree) &&
	rm -f .shit/index &&
	tail -n 10 LIST | shit update-index --index-info &&
	ST=$(shit write-tree) &&
	shit rev-list --objects "$LIST" "$LI" "$ST" >actual &&
	PACK5=$( shit pack-objects test-5 <actual ) &&
	PACK6=$( test_write_lines "$LIST" "$LI" "$ST" | shit pack-objects test-6 ) &&
	test_create_repo test-5 &&
	(
		cd test-5 &&
		shit unpack-objects --strict <../test-5-$PACK5.pack &&
		shit ls-tree -r $LIST &&
		shit ls-tree -r $LI &&
		shit ls-tree -r $ST
	) &&
	test_create_repo test-6 &&
	(
		# tree-only into empty repo -- many unreachables
		cd test-6 &&
		test_must_fail shit unpack-objects --strict <../test-6-$PACK6.pack
	) &&
	(
		# already populated -- no unreachables
		cd test-5 &&
		shit unpack-objects --strict <../test-6-$PACK6.pack
	)
'

test_expect_success 'index-pack with --strict' '

	for j in a b c d e f g
	do
		for i in 0 1 2 3 4 5 6 7 8 9
		do
			o=$(echo $j$i | shit hash-object -w --stdin) &&
			echo "100644 $o	0 $j$i" || return 1
		done
	done >LIST &&
	rm -f .shit/index &&
	shit update-index --index-info <LIST &&
	LIST=$(shit write-tree) &&
	rm -f .shit/index &&
	head -n 10 LIST | shit update-index --index-info &&
	LI=$(shit write-tree) &&
	rm -f .shit/index &&
	tail -n 10 LIST | shit update-index --index-info &&
	ST=$(shit write-tree) &&
	shit rev-list --objects "$LIST" "$LI" "$ST" >actual &&
	PACK5=$( shit pack-objects test-5 <actual ) &&
	PACK6=$( test_write_lines "$LIST" "$LI" "$ST" | shit pack-objects test-6 ) &&
	test_create_repo test-7 &&
	(
		cd test-7 &&
		shit index-pack --strict --stdin <../test-5-$PACK5.pack &&
		shit ls-tree -r $LIST &&
		shit ls-tree -r $LI &&
		shit ls-tree -r $ST
	) &&
	test_create_repo test-8 &&
	(
		# tree-only into empty repo -- many unreachables
		cd test-8 &&
		test_must_fail shit index-pack --strict --stdin <../test-6-$PACK6.pack
	) &&
	(
		# already populated -- no unreachables
		cd test-7 &&
		shit index-pack --strict --stdin <../test-6-$PACK6.pack
	)
'

test_expect_success 'setup for --strict and --fsck-objects downgrading fsck msgs' '
	shit init strict &&
	(
		cd strict &&
		test_commit first hello &&
		cat >commit <<-EOF &&
		tree $(shit rev-parse HEAD^{tree})
		parent $(shit rev-parse HEAD)
		author A U Thor
		committer A U Thor

		commit: this is a commit with bad emails

		EOF
		shit hash-object --literally -t commit -w --stdin <commit >commit_list &&
		shit pack-objects test <commit_list >pack-name
	)
'

test_with_bad_commit () {
	must_fail_arg="$1" &&
	must_pass_arg="$2" &&
	(
		cd strict &&
		test_must_fail shit index-pack "$must_fail_arg" "test-$(cat pack-name).pack" &&
		shit index-pack "$must_pass_arg" "test-$(cat pack-name).pack"
	)
}

test_expect_success 'index-pack with --strict downgrading fsck msgs' '
	test_with_bad_commit --strict --strict="missingEmail=ignore"
'

test_expect_success 'index-pack with --fsck-objects downgrading fsck msgs' '
	test_with_bad_commit --fsck-objects --fsck-objects="missingEmail=ignore"
'

test_expect_success 'cleanup for --strict and --fsck-objects downgrading fsck msgs' '
	rm -rf strict
'

test_expect_success 'honor pack.packSizeLimit' '
	shit config pack.packSizeLimit 3m &&
	packname_10=$(shit pack-objects test-10 <obj-list) &&
	test 2 = $(ls test-10-*.pack | wc -l)
'

test_expect_success 'verify resulting packs' '
	shit verify-pack test-10-*.pack
'

test_expect_success 'tolerate packsizelimit smaller than biggest object' '
	shit config pack.packSizeLimit 1 &&
	packname_11=$(shit pack-objects test-11 <obj-list) &&
	test 5 = $(ls test-11-*.pack | wc -l)
'

test_expect_success 'verify resulting packs' '
	shit verify-pack test-11-*.pack
'

test_expect_success 'set up pack for non-repo tests' '
	# make sure we have a pack with no matching index file
	cp test-1-*.pack foo.pack
'

test_expect_success 'index-pack --stdin complains of non-repo' '
	nonshit test_must_fail shit index-pack --object-format=$(test_oid algo) --stdin <foo.pack &&
	test_path_is_missing non-repo/.shit
'

test_expect_success 'index-pack <pack> works in non-repo' '
	nonshit shit index-pack --object-format=$(test_oid algo) ../foo.pack &&
	test_path_is_file foo.idx
'

test_expect_success 'index-pack --strict <pack> works in non-repo' '
	rm -f foo.idx &&
	nonshit shit index-pack --strict --object-format=$(test_oid algo) ../foo.pack &&
	test_path_is_file foo.idx
'

test_expect_success !PTHREADS,!FAIL_PREREQS \
	'index-pack --threads=N or pack.threads=N warns when no pthreads' '
	test_must_fail shit index-pack --threads=2 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 1 warnings &&
	grep -F "no threads support, ignoring --threads=2" err &&

	test_must_fail shit -c pack.threads=2 index-pack 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 1 warnings &&
	grep -F "no threads support, ignoring pack.threads" err &&

	test_must_fail shit -c pack.threads=2 index-pack --threads=4 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 2 warnings &&
	grep -F "no threads support, ignoring --threads=4" err &&
	grep -F "no threads support, ignoring pack.threads" err
'

test_expect_success !PTHREADS,!FAIL_PREREQS \
	'pack-objects --threads=N or pack.threads=N warns when no pthreads' '
	shit pack-objects --threads=2 --stdout --all </dev/null >/dev/null 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 1 warnings &&
	grep -F "no threads support, ignoring --threads" err &&

	shit -c pack.threads=2 pack-objects --stdout --all </dev/null >/dev/null 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 1 warnings &&
	grep -F "no threads support, ignoring pack.threads" err &&

	shit -c pack.threads=2 pack-objects --threads=4 --stdout --all </dev/null >/dev/null 2>err &&
	grep ^warning: err >warnings &&
	test_line_count = 2 warnings &&
	grep -F "no threads support, ignoring --threads" err &&
	grep -F "no threads support, ignoring pack.threads" err
'

test_expect_success 'pack-objects in too-many-packs mode' '
	shit_TEST_FULL_IN_PACK_ARRAY=1 shit repack -ad &&
	shit fsck
'

test_expect_success 'setup: fake a SHA1 hash collision' '
	shit init corrupt &&
	(
		cd corrupt &&
		long_a=$(shit hash-object -w ../a | sed -e "s!^..!&/!") &&
		long_b=$(shit hash-object -w ../b | sed -e "s!^..!&/!") &&
		test -f	.shit/objects/$long_b &&
		cp -f	.shit/objects/$long_a \
			.shit/objects/$long_b
	)
'

test_expect_success 'make sure index-pack detects the SHA1 collision' '
	(
		cd corrupt &&
		test_must_fail shit index-pack -o ../bad.idx ../test-3.pack 2>msg &&
		test_grep "SHA1 COLLISION FOUND" msg
	)
'

test_expect_success 'make sure index-pack detects the SHA1 collision (large blobs)' '
	(
		cd corrupt &&
		test_must_fail shit -c core.bigfilethreshold=1 index-pack -o ../bad.idx ../test-3.pack 2>msg &&
		test_grep "SHA1 COLLISION FOUND" msg
	)
'

test_expect_success 'prefetch objects' '
	rm -rf server client &&

	shit init server &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server protocol.version 2 &&

	echo one >server/one &&
	shit -C server add one &&
	shit -C server commit -m one &&
	shit -C server branch one_branch &&

	echo two_a >server/two_a &&
	echo two_b >server/two_b &&
	shit -C server add two_a two_b &&
	shit -C server commit -m two &&

	echo three >server/three &&
	shit -C server add three &&
	shit -C server commit -m three &&
	shit -C server branch three_branch &&

	# Clone, fetch "two" with blobs excluded, and re-defecate it. This requires
	# the client to have the blobs of "two" - verify that these are
	# prefetched in one batch.
	shit clone --filter=blob:none --single-branch -b one_branch \
		"file://$(pwd)/server" client &&
	test_config -C client protocol.version 2 &&
	TWO=$(shit -C server rev-parse three_branch^) &&
	shit -C client fetch --filter=blob:none origin "$TWO" &&
	shit_TRACE_PACKET=$(pwd)/trace shit -C client defecate origin "$TWO":refs/heads/two_branch &&
	grep "fetch> done" trace >donelines &&
	test_line_count = 1 donelines
'

test_expect_success 'negative window clamps to 0' '
	shit pack-objects --progress --window=-1 neg-window <obj-list 2>stderr &&
	check_deltas stderr = 0
'

test_done
