#!/bin/sh

test_description='multi-pack-indexes'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-chunk.sh

shit_TEST_MULTI_PACK_INDEX=0
objdir=.shit/objects

HASH_LEN=$(test_oid rawsz)

midx_read_expect () {
	NUM_PACKS=$1
	NUM_OBJECTS=$2
	NUM_CHUNKS=$3
	OBJECT_DIR=$4
	EXTRA_CHUNKS="$5"
	{
		cat <<-EOF &&
		header: 4d494458 1 $HASH_LEN $NUM_CHUNKS $NUM_PACKS
		chunks: pack-names oid-fanout oid-lookup object-offsets$EXTRA_CHUNKS
		num_objects: $NUM_OBJECTS
		packs:
		EOF
		if test $NUM_PACKS -ge 1
		then
			ls $OBJECT_DIR/pack/ | grep idx | sort
		fi &&
		printf "object-dir: $OBJECT_DIR\n"
	} >expect &&
	test-tool read-midx $OBJECT_DIR >actual &&
	test_cmp expect actual
}

test_expect_success 'setup' '
	test_oid_cache <<-EOF
	idxoff sha1:2999
	idxoff sha256:3739

	packnameoff sha1:652
	packnameoff sha256:940

	fanoutoff sha1:1
	fanoutoff sha256:3
	EOF
'

test_expect_success "don't write midx with no packs" '
	test_must_fail shit multi-pack-index --object-dir=. write &&
	test_path_is_missing pack/multi-pack-index
'

test_expect_success SHA1 'warn if a midx contains no oid' '
	cp "$TEST_DIRECTORY"/t5319/no-objects.midx $objdir/pack/multi-pack-index &&
	test_must_fail shit multi-pack-index verify &&
	rm $objdir/pack/multi-pack-index
'

generate_objects () {
	i=$1
	iii=$(printf '%03i' $i)
	{
		test-tool genrandom "bar" 200 &&
		test-tool genrandom "baz $iii" 50
	} >wide_delta_$iii &&
	{
		test-tool genrandom "foo"$i 100 &&
		test-tool genrandom "foo"$(( $i + 1 )) 100 &&
		test-tool genrandom "foo"$(( $i + 2 )) 100
	} >deep_delta_$iii &&
	{
		echo $iii &&
		test-tool genrandom "$iii" 8192
	} >file_$iii &&
	shit update-index --add file_$iii deep_delta_$iii wide_delta_$iii
}

commit_and_list_objects () {
	{
		echo 101 &&
		test-tool genrandom 100 8192;
	} >file_101 &&
	shit update-index --add file_101 &&
	tree=$(shit write-tree) &&
	commit=$(shit commit-tree $tree -p HEAD</dev/null) &&
	{
		echo $tree &&
		shit ls-tree $tree | sed -e "s/.* \\([0-9a-f]*\\)	.*/\\1/"
	} >obj-list &&
	shit reset --hard $commit
}

test_expect_success 'create objects' '
	test_commit initial &&
	for i in $(test_seq 1 5)
	do
		generate_objects $i || return 1
	done &&
	commit_and_list_objects
'

test_expect_success 'write midx with one v1 pack' '
	pack=$(shit pack-objects --index-version=1 $objdir/pack/test <obj-list) &&
	test_when_finished rm $objdir/pack/test-$pack.pack \
		$objdir/pack/test-$pack.idx $objdir/pack/multi-pack-index &&
	shit multi-pack-index --object-dir=$objdir write &&
	midx_read_expect 1 18 4 $objdir
'

midx_shit_two_modes () {
	shit -c core.multiPackIndex=false $1 >expect &&
	shit -c core.multiPackIndex=true $1 >actual &&
	if [ "$2" = "sorted" ]
	then
		sort <expect >expect.sorted &&
		mv expect.sorted expect &&
		sort <actual >actual.sorted &&
		mv actual.sorted actual
	fi &&
	test_cmp expect actual
}

compare_results_with_midx () {
	MSG=$1
	test_expect_success "check normal shit operations: $MSG" '
		midx_shit_two_modes "rev-list --objects --all" &&
		midx_shit_two_modes "log --raw" &&
		midx_shit_two_modes "count-objects --verbose" &&
		midx_shit_two_modes "cat-file --batch-all-objects --batch-check" &&
		midx_shit_two_modes "cat-file --batch-all-objects --batch-check --unordered" sorted
	'
}

test_expect_success 'write midx with one v2 pack' '
	shit pack-objects --index-version=2,0x40 $objdir/pack/test <obj-list &&
	shit multi-pack-index --object-dir=$objdir write &&
	midx_read_expect 1 18 4 $objdir
'

compare_results_with_midx "one v2 pack"

test_expect_success 'corrupt idx reports errors' '
	idx=$(test-tool read-midx $objdir | grep "\.idx\$") &&
	mv $objdir/pack/$idx backup-$idx &&
	test_when_finished "mv backup-\$idx \$objdir/pack/\$idx" &&

	# This is the minimum size for a sha-1 based .idx; this lets
	# us pass perfunctory tests, but anything that actually opens and reads
	# the idx file will complain.
	test_copy_bytes 1064 <backup-$idx >$objdir/pack/$idx &&

	shit -c core.multiPackIndex=true rev-list --objects --all 2>err &&
	grep "index unavailable" err
'

test_expect_success 'add more objects' '
	for i in $(test_seq 6 10)
	do
		generate_objects $i || return 1
	done &&
	commit_and_list_objects
'

test_expect_success 'write midx with two packs' '
	shit pack-objects --index-version=1 $objdir/pack/test-2 <obj-list &&
	shit multi-pack-index --object-dir=$objdir write &&
	midx_read_expect 2 34 4 $objdir
'

compare_results_with_midx "two packs"

test_expect_success 'write midx with --stdin-packs' '
	rm -fr $objdir/pack/multi-pack-index &&

	idx="$(find $objdir/pack -name "test-2-*.idx")" &&
	basename "$idx" >in &&

	shit multi-pack-index write --stdin-packs <in &&

	test-tool read-midx $objdir | grep "\.idx$" >packs &&

	test_cmp packs in
'

compare_results_with_midx "mixed mode (one pack + extra)"

test_expect_success 'write with no objects and preferred pack' '
	test_when_finished "rm -rf empty" &&
	shit init empty &&
	test_must_fail shit -C empty multi-pack-index write \
		--stdin-packs --preferred-pack=does-not-exist </dev/null 2>err &&
	cat >expect <<-EOF &&
	warning: unknown preferred pack: ${SQ}does-not-exist${SQ}
	error: no pack files to index.
	EOF
	test_cmp expect err
'

test_expect_success 'write progress off for redirected stderr' '
	shit multi-pack-index --object-dir=$objdir write 2>err &&
	test_line_count = 0 err
'

test_expect_success 'write force progress on for stderr' '
	shit_PROGRESS_DELAY=0 shit multi-pack-index --object-dir=$objdir write --progress 2>err &&
	test_file_not_empty err
'

test_expect_success 'write with the --no-progress option' '
	shit_PROGRESS_DELAY=0 shit multi-pack-index --object-dir=$objdir write --no-progress 2>err &&
	test_line_count = 0 err
'

test_expect_success 'add more packs' '
	for j in $(test_seq 11 20)
	do
		generate_objects $j &&
		commit_and_list_objects &&
		shit pack-objects --index-version=2 $objdir/pack/test-pack <obj-list || return 1
	done
'

compare_results_with_midx "mixed mode (two packs + extra)"

test_expect_success 'write midx with twelve packs' '
	shit multi-pack-index --object-dir=$objdir write &&
	midx_read_expect 12 74 4 $objdir
'

compare_results_with_midx "twelve packs"

test_expect_success 'multi-pack-index *.rev cleanup with --object-dir' '
	shit init repo &&
	shit clone -s repo alternate &&

	test_when_finished "rm -rf repo alternate" &&

	(
		cd repo &&
		test_commit base &&
		shit repack -d
	) &&

	ours="alternate/.shit/objects/pack/multi-pack-index-123.rev" &&
	theirs="repo/.shit/objects/pack/multi-pack-index-abc.rev" &&
	touch "$ours" "$theirs" &&

	(
		cd alternate &&
		shit multi-pack-index --object-dir ../repo/.shit/objects write
	) &&

	# writing a midx in "repo" should not remove the .rev file in the
	# alternate
	test_path_is_file repo/.shit/objects/pack/multi-pack-index &&
	test_path_is_file $ours &&
	test_path_is_missing $theirs
'

test_expect_success 'warn on improper hash version' '
	shit init --object-format=sha1 sha1 &&
	(
		cd sha1 &&
		shit config core.multiPackIndex true &&
		test_commit 1 &&
		shit repack -a &&
		shit multi-pack-index write &&
		mv .shit/objects/pack/multi-pack-index ../mpi-sha1
	) &&
	shit init --object-format=sha256 sha256 &&
	(
		cd sha256 &&
		shit config core.multiPackIndex true &&
		test_commit 1 &&
		shit repack -a &&
		shit multi-pack-index write &&
		mv .shit/objects/pack/multi-pack-index ../mpi-sha256
	) &&
	(
		cd sha1 &&
		mv ../mpi-sha256 .shit/objects/pack/multi-pack-index &&
		shit log -1 2>err &&
		test_grep "multi-pack-index hash version 2 does not match version 1" err
	) &&
	(
		cd sha256 &&
		mv ../mpi-sha1 .shit/objects/pack/multi-pack-index &&
		shit log -1 2>err &&
		test_grep "multi-pack-index hash version 1 does not match version 2" err
	)
'

test_expect_success 'midx picks objects from preferred pack' '
	test_when_finished rm -rf preferred.shit &&
	shit init --bare preferred.shit &&
	(
		cd preferred.shit &&

		a=$(echo "a" | shit hash-object -w --stdin) &&
		b=$(echo "b" | shit hash-object -w --stdin) &&
		c=$(echo "c" | shit hash-object -w --stdin) &&

		# Set up two packs, duplicating the object "B" at different
		# offsets.
		#
		# Note that the "BC" pack (the one we choose as preferred) sorts
		# lexically after the "AB" pack, meaning that omitting the
		# --preferred-pack argument would cause this test to fail (since
		# the MIDX code would select the copy of "b" in the "AB" pack).
		shit pack-objects objects/pack/test-AB <<-EOF &&
		$a
		$b
		EOF
		bc=$(shit pack-objects objects/pack/test-BC <<-EOF
		$b
		$c
		EOF
		) &&

		shit multi-pack-index --object-dir=objects \
			write --preferred-pack=test-BC-$bc.idx 2>err &&
		test_must_be_empty err &&

		test-tool read-midx --show-objects objects >out &&

		ofs=$(shit show-index <objects/pack/test-BC-$bc.idx | grep $b |
			cut -d" " -f1) &&
		printf "%s %s\tobjects/pack/test-BC-%s.pack\n" \
			"$b" "$ofs" "$bc" >expect &&
		grep ^$b out >actual &&

		test_cmp expect actual
	)
'

test_expect_success 'preferred packs must be non-empty' '
	test_when_finished rm -rf preferred.shit &&
	shit init preferred.shit &&
	(
		cd preferred.shit &&

		test_commit base &&
		shit repack -ad &&

		empty="$(shit pack-objects $objdir/pack/pack </dev/null)" &&

		test_must_fail shit multi-pack-index write \
			--preferred-pack=pack-$empty.pack 2>err &&
		grep "with no objects" err
	)
'

test_expect_success 'verify multi-pack-index success' '
	shit multi-pack-index verify --object-dir=$objdir
'

test_expect_success 'verify progress off for redirected stderr' '
	shit multi-pack-index verify --object-dir=$objdir 2>err &&
	test_line_count = 0 err
'

test_expect_success 'verify force progress on for stderr' '
	shit multi-pack-index verify --object-dir=$objdir --progress 2>err &&
	test_file_not_empty err
'

test_expect_success 'verify with the --no-progress option' '
	shit multi-pack-index verify --object-dir=$objdir --no-progress 2>err &&
	test_line_count = 0 err
'

# usage: corrupt_midx_and_verify <pos> <data> <objdir> <string>
corrupt_midx_and_verify() {
	POS=$1 &&
	DATA="${2:-\0}" &&
	OBJDIR=$3 &&
	GREPSTR="$4" &&
	COMMAND="$5" &&
	if test -z "$COMMAND"
	then
		COMMAND="shit multi-pack-index verify --object-dir=$OBJDIR"
	fi &&
	FILE=$OBJDIR/pack/multi-pack-index &&
	chmod a+w $FILE &&
	test_when_finished mv midx-backup $FILE &&
	cp $FILE midx-backup &&
	printf "$DATA" | dd of="$FILE" bs=1 seek="$POS" conv=notrunc &&
	test_must_fail $COMMAND 2>test_err &&
	grep -v "^+" test_err >err &&
	test_grep "$GREPSTR" err
}

test_expect_success 'verify bad signature' '
	corrupt_midx_and_verify 0 "\00" $objdir \
		"multi-pack-index signature"
'

NUM_OBJECTS=74
MIDX_BYTE_VERSION=4
MIDX_BYTE_OID_VERSION=5
MIDX_BYTE_CHUNK_COUNT=6
MIDX_HEADER_SIZE=12
MIDX_BYTE_CHUNK_ID=$MIDX_HEADER_SIZE
MIDX_BYTE_CHUNK_OFFSET=$(($MIDX_HEADER_SIZE + 4))
MIDX_NUM_CHUNKS=5
MIDX_CHUNK_LOOKUP_WIDTH=12
MIDX_OFFSET_PACKNAMES=$(($MIDX_HEADER_SIZE + \
			 $MIDX_NUM_CHUNKS * $MIDX_CHUNK_LOOKUP_WIDTH))
MIDX_BYTE_PACKNAME_ORDER=$(($MIDX_OFFSET_PACKNAMES + 2))
MIDX_OFFSET_OID_FANOUT=$(($MIDX_OFFSET_PACKNAMES + $(test_oid packnameoff)))
MIDX_OID_FANOUT_WIDTH=4
MIDX_BYTE_OID_FANOUT_ORDER=$((MIDX_OFFSET_OID_FANOUT + 250 * $MIDX_OID_FANOUT_WIDTH + $(test_oid fanoutoff)))
MIDX_OFFSET_OID_LOOKUP=$(($MIDX_OFFSET_OID_FANOUT + 256 * $MIDX_OID_FANOUT_WIDTH))
MIDX_BYTE_OID_LOOKUP=$(($MIDX_OFFSET_OID_LOOKUP + 16 * $HASH_LEN))
MIDX_OFFSET_OBJECT_OFFSETS=$(($MIDX_OFFSET_OID_LOOKUP + $NUM_OBJECTS * $HASH_LEN))
MIDX_OFFSET_WIDTH=8
MIDX_BYTE_PACK_INT_ID=$(($MIDX_OFFSET_OBJECT_OFFSETS + 16 * $MIDX_OFFSET_WIDTH + 2))
MIDX_BYTE_OFFSET=$(($MIDX_OFFSET_OBJECT_OFFSETS + 16 * $MIDX_OFFSET_WIDTH + 6))

test_expect_success 'verify bad version' '
	corrupt_midx_and_verify $MIDX_BYTE_VERSION "\00" $objdir \
		"multi-pack-index version"
'

test_expect_success 'verify bad OID version' '
	corrupt_midx_and_verify $MIDX_BYTE_OID_VERSION "\03" $objdir \
		"hash version"
'

test_expect_success 'verify truncated chunk count' '
	corrupt_midx_and_verify $MIDX_BYTE_CHUNK_COUNT "\01" $objdir \
		"final chunk has non-zero id"
'

test_expect_success 'verify extended chunk count' '
	corrupt_midx_and_verify $MIDX_BYTE_CHUNK_COUNT "\07" $objdir \
		"terminating chunk id appears earlier than expected"
'

test_expect_success 'verify missing required chunk' '
	corrupt_midx_and_verify $MIDX_BYTE_CHUNK_ID "\01" $objdir \
		"required pack-name chunk missing"
'

test_expect_success 'verify invalid chunk offset' '
	corrupt_midx_and_verify $MIDX_BYTE_CHUNK_OFFSET "\01" $objdir \
		"improper chunk offset(s)"
'

test_expect_success 'verify packnames out of order' '
	corrupt_midx_and_verify $MIDX_BYTE_PACKNAME_ORDER "z" $objdir \
		"pack names out of order"
'

test_expect_success 'verify packnames out of order' '
	corrupt_midx_and_verify $MIDX_BYTE_PACKNAME_ORDER "a" $objdir \
		"failed to load pack"
'

test_expect_success 'verify oid fanout out of order' '
	corrupt_midx_and_verify $MIDX_BYTE_OID_FANOUT_ORDER "\01" $objdir \
		"oid fanout out of order"
'

test_expect_success 'verify oid lookup out of order' '
	corrupt_midx_and_verify $MIDX_BYTE_OID_LOOKUP "\00" $objdir \
		"oid lookup out of order"
'

test_expect_success 'verify incorrect pack-int-id' '
	corrupt_midx_and_verify $MIDX_BYTE_PACK_INT_ID "\07" $objdir \
		"bad pack-int-id"
'

test_expect_success 'verify incorrect offset' '
	corrupt_midx_and_verify $MIDX_BYTE_OFFSET "\377" $objdir \
		"incorrect object offset"
'

test_expect_success 'shit-fsck incorrect offset' '
	corrupt_midx_and_verify $MIDX_BYTE_OFFSET "\377" $objdir \
		"incorrect object offset" \
		"shit -c core.multiPackIndex=true fsck" &&
	test_unconfig core.multiPackIndex &&
	test_must_fail shit fsck &&
	shit -c core.multiPackIndex=false fsck
'

test_expect_success 'shit fsck shows MIDX output with --progress' '
	shit fsck --progress 2>err &&
	grep "Verifying OID order in multi-pack-index" err &&
	grep "Verifying object offsets" err
'

test_expect_success 'shit fsck suppresses MIDX output with --no-progress' '
	shit fsck --no-progress 2>err &&
	! grep "Verifying OID order in multi-pack-index" err &&
	! grep "Verifying object offsets" err
'

test_expect_success 'corrupt MIDX is not reused' '
	corrupt_midx_and_verify $MIDX_BYTE_OFFSET "\377" $objdir \
		"incorrect object offset" &&
	shit multi-pack-index write 2>err &&
	test_grep checksum.mismatch err &&
	shit multi-pack-index verify
'

test_expect_success 'verify incorrect checksum' '
	pos=$(($(wc -c <$objdir/pack/multi-pack-index) - 10)) &&
	corrupt_midx_and_verify $pos \
		"\377\377\377\377\377\377\377\377\377\377" \
		$objdir "incorrect checksum"
'

test_expect_success 'repack progress off for redirected stderr' '
	shit_PROGRESS_DELAY=0 shit multi-pack-index --object-dir=$objdir repack 2>err &&
	test_line_count = 0 err
'

test_expect_success 'repack force progress on for stderr' '
	shit_PROGRESS_DELAY=0 shit multi-pack-index --object-dir=$objdir repack --progress 2>err &&
	test_file_not_empty err
'

test_expect_success 'repack with the --no-progress option' '
	shit_PROGRESS_DELAY=0 shit multi-pack-index --object-dir=$objdir repack --no-progress 2>err &&
	test_line_count = 0 err
'

test_expect_success 'repack removes multi-pack-index when deleting packs' '
	test_path_is_file $objdir/pack/multi-pack-index &&
	# Set shit_TEST_MULTI_PACK_INDEX to 0 to avoid writing a new
	# multi-pack-index after repacking, but set "core.multiPackIndex" to
	# true so that "shit repack" can read the existing MIDX.
	shit_TEST_MULTI_PACK_INDEX=0 shit -c core.multiPackIndex repack -adf &&
	test_path_is_missing $objdir/pack/multi-pack-index
'

test_expect_success 'repack preserves multi-pack-index when creating packs' '
	shit init preserve &&
	test_when_finished "rm -fr preserve" &&
	(
		cd preserve &&
		packdir=.shit/objects/pack &&
		midx=$packdir/multi-pack-index &&

		test_commit 1 &&
		pack1=$(shit pack-objects --all $packdir/pack) &&
		touch $packdir/pack-$pack1.keep &&
		test_commit 2 &&
		pack2=$(shit pack-objects --revs $packdir/pack) &&
		touch $packdir/pack-$pack2.keep &&

		shit multi-pack-index write &&
		cp $midx $midx.bak &&

		cat >pack-input <<-EOF &&
		HEAD
		^HEAD~1
		EOF
		test_commit 3 &&
		pack3=$(shit pack-objects --revs $packdir/pack <pack-input) &&
		test_commit 4 &&
		pack4=$(shit pack-objects --revs $packdir/pack <pack-input) &&

		shit_TEST_MULTI_PACK_INDEX=0 shit -c core.multiPackIndex repack -ad &&
		ls -la $packdir &&
		test_path_is_file $packdir/pack-$pack1.pack &&
		test_path_is_file $packdir/pack-$pack2.pack &&
		test_path_is_missing $packdir/pack-$pack3.pack &&
		test_path_is_missing $packdir/pack-$pack4.pack &&
		test_cmp_bin $midx.bak $midx
	)
'

compare_results_with_midx "after repack"

test_expect_success 'multi-pack-index and pack-bitmap' '
	shit_TEST_MULTI_PACK_INDEX_WRITE_BITMAP=0 \
		shit -c repack.writeBitmaps=true repack -ad &&
	shit multi-pack-index write &&
	shit rev-list --test-bitmap HEAD
'

test_expect_success 'multi-pack-index and alternates' '
	shit init --bare alt.shit &&
	echo $(pwd)/alt.shit/objects >.shit/objects/info/alternates &&
	echo content1 >file1 &&
	altblob=$(shit_DIR=alt.shit shit hash-object -w file1) &&
	shit cat-file blob $altblob &&
	shit rev-list --all
'

compare_results_with_midx "with alternate (local midx)"

test_expect_success 'multi-pack-index in an alternate' '
	mv .shit/objects/pack/* alt.shit/objects/pack &&
	test_commit add_local_objects &&
	shit repack --local &&
	shit multi-pack-index write &&
	midx_read_expect 1 3 4 $objdir &&
	shit reset --hard HEAD~1 &&
	rm -f .shit/objects/pack/*
'

compare_results_with_midx "with alternate (remote midx)"

# usage: corrupt_data <file> <pos> [<data>]
corrupt_data () {
	file=$1
	pos=$2
	data="${3:-\0}"
	printf "$data" | dd of="$file" bs=1 seek="$pos" conv=notrunc
}

# Force 64-bit offsets by manipulating the idx file.
# This makes the IDX file _incorrect_ so be careful to clean up after!
test_expect_success 'force some 64-bit offsets with pack-objects' '
	mkdir objects64 &&
	mkdir objects64/pack &&
	for i in $(test_seq 1 11)
	do
		generate_objects 11 || return 1
	done &&
	commit_and_list_objects &&
	pack64=$(shit pack-objects --index-version=2,0x40 objects64/pack/test-64 <obj-list) &&
	idx64=objects64/pack/test-64-$pack64.idx &&
	chmod u+w $idx64 &&
	corrupt_data $idx64 $(test_oid idxoff) "\02" &&
	# objects64 is not a real repository, but can serve as an alternate
	# anyway so we can write a MIDX into it
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&
		( cd ../objects64 && pwd ) >.shit/objects/info/alternates &&
		midx64=$(shit multi-pack-index --object-dir=../objects64 write)
	) &&
	midx_read_expect 1 63 5 objects64 " large-offsets"
'

test_expect_success 'verify multi-pack-index with 64-bit offsets' '
	shit multi-pack-index verify --object-dir=objects64
'

NUM_OBJECTS=63
MIDX_OFFSET_OID_FANOUT=$((MIDX_OFFSET_PACKNAMES + 54))
MIDX_OFFSET_OID_LOOKUP=$((MIDX_OFFSET_OID_FANOUT + 256 * $MIDX_OID_FANOUT_WIDTH))
MIDX_OFFSET_OBJECT_OFFSETS=$(($MIDX_OFFSET_OID_LOOKUP + $NUM_OBJECTS * $HASH_LEN))
MIDX_OFFSET_LARGE_OFFSETS=$(($MIDX_OFFSET_OBJECT_OFFSETS + $NUM_OBJECTS * $MIDX_OFFSET_WIDTH))
MIDX_BYTE_LARGE_OFFSET=$(($MIDX_OFFSET_LARGE_OFFSETS + 3))

test_expect_success 'verify incorrect 64-bit offset' '
	corrupt_midx_and_verify $MIDX_BYTE_LARGE_OFFSET "\07" objects64 \
		"incorrect object offset"
'

test_expect_success 'setup expire tests' '
	mkdir dup &&
	(
		cd dup &&
		shit init &&
		test-tool genrandom "data" 4096 >large_file.txt &&
		shit update-index --add large_file.txt &&
		for i in $(test_seq 1 20)
		do
			test_commit $i || exit 1
		done &&
		shit branch A HEAD &&
		shit branch B HEAD~8 &&
		shit branch C HEAD~13 &&
		shit branch D HEAD~16 &&
		shit branch E HEAD~18 &&
		shit pack-objects --revs .shit/objects/pack/pack-A <<-EOF &&
		refs/heads/A
		^refs/heads/B
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-B <<-EOF &&
		refs/heads/B
		^refs/heads/C
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-C <<-EOF &&
		refs/heads/C
		^refs/heads/D
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-D <<-EOF &&
		refs/heads/D
		^refs/heads/E
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-E <<-EOF &&
		refs/heads/E
		EOF
		shit multi-pack-index write &&
		cp -r .shit/objects/pack .shit/objects/pack-backup
	)
'

test_expect_success 'expire does not remove any packs' '
	(
		cd dup &&
		ls .shit/objects/pack >expect &&
		shit multi-pack-index expire &&
		ls .shit/objects/pack >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'expire progress off for redirected stderr' '
	(
		cd dup &&
		shit multi-pack-index expire 2>err &&
		test_line_count = 0 err
	)
'

test_expect_success 'expire force progress on for stderr' '
	(
		cd dup &&
		shit_PROGRESS_DELAY=0 shit multi-pack-index expire --progress 2>err &&
		test_file_not_empty err
	)
'

test_expect_success 'expire with the --no-progress option' '
	(
		cd dup &&
		shit_PROGRESS_DELAY=0 shit multi-pack-index expire --no-progress 2>err &&
		test_line_count = 0 err
	)
'

test_expect_success 'expire removes unreferenced packs' '
	(
		cd dup &&
		shit pack-objects --revs .shit/objects/pack/pack-combined <<-EOF &&
		refs/heads/A
		^refs/heads/C
		EOF
		shit multi-pack-index write &&
		ls .shit/objects/pack | grep -v -e pack-[AB] >expect &&
		shit multi-pack-index expire &&
		ls .shit/objects/pack >actual &&
		test_cmp expect actual &&
		ls .shit/objects/pack/ | grep idx >expect-idx &&
		test-tool read-midx .shit/objects | grep idx >actual-midx &&
		test_cmp expect-idx actual-midx &&
		shit multi-pack-index verify &&
		shit fsck
	)
'

test_expect_success 'repack with minimum size does not alter existing packs' '
	(
		cd dup &&
		rm -rf .shit/objects/pack &&
		mv .shit/objects/pack-backup .shit/objects/pack &&
		test-tool chmtime =-5 .shit/objects/pack/pack-D* &&
		test-tool chmtime =-4 .shit/objects/pack/pack-C* &&
		test-tool chmtime =-3 .shit/objects/pack/pack-B* &&
		test-tool chmtime =-2 .shit/objects/pack/pack-A* &&
		ls .shit/objects/pack >expect &&
		MINSIZE=$(test-tool path-utils file-size .shit/objects/pack/*pack | sort -n | head -n 1) &&
		shit multi-pack-index repack --batch-size=$MINSIZE &&
		ls .shit/objects/pack >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'repack respects repack.packKeptObjects=false' '
	test_when_finished rm -f dup/.shit/objects/pack/*keep &&
	(
		cd dup &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 5 idx-list &&
		ls .shit/objects/pack/*.pack | sed "s/\.pack/.keep/" >keep-list &&
		test_line_count = 5 keep-list &&
		for keep in $(cat keep-list)
		do
			touch $keep || return 1
		done &&
		shit multi-pack-index repack --batch-size=0 &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 5 idx-list &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 5 midx-list &&
		THIRD_SMALLEST_SIZE=$(test-tool path-utils file-size .shit/objects/pack/*pack | sort -n | sed -n 3p) &&
		BATCH_SIZE=$((THIRD_SMALLEST_SIZE + 1)) &&
		shit multi-pack-index repack --batch-size=$BATCH_SIZE &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 5 idx-list &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 5 midx-list
	)
'

test_expect_success 'repack creates a new pack' '
	(
		cd dup &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 5 idx-list &&
		THIRD_SMALLEST_SIZE=$(test-tool path-utils file-size .shit/objects/pack/*pack | sort -n | head -n 3 | tail -n 1) &&
		BATCH_SIZE=$(($THIRD_SMALLEST_SIZE + 1)) &&
		shit multi-pack-index repack --batch-size=$BATCH_SIZE &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 6 idx-list &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 6 midx-list
	)
'

test_expect_success 'repack (all) ignores cruft pack' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		test_commit base &&
		test_commit --no-tag unreachable &&

		shit reset --hard base &&
		shit reflog expire --all --expire=all &&
		shit repack --cruft -d &&

		shit multi-pack-index write &&

		find $objdir/pack | sort >before &&
		shit multi-pack-index repack --batch-size=0 &&
		find $objdir/pack | sort >after &&

		test_cmp before after
	)
'

test_expect_success 'repack (--batch-size) ignores cruft pack' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		test_commit_bulk 5 &&
		test_commit --no-tag unreachable &&

		shit reset --hard HEAD^ &&
		shit reflog expire --all --expire=all &&
		shit repack --cruft -d &&

		test_commit four &&

		find $objdir/pack -type f -name "*.pack" | sort >before &&
		shit repack -d &&
		find $objdir/pack -type f -name "*.pack" | sort >after &&

		pack="$(comm -13 before after)" &&
		test_file_size "$pack" >sz &&
		# Set --batch-size to twice the size of the pack created
		# in the previous step, since this is enough to
		# accommodate it and the cruft pack.
		#
		# This means that the MIDX machinery *could* combine the
		# new and cruft packs together.
		#
		# We ensure that it does not below.
		batch="$((($(cat sz) * 2)))" &&

		shit multi-pack-index write &&

		find $objdir/pack | sort >before &&
		shit multi-pack-index repack --batch-size=$batch &&
		find $objdir/pack | sort >after &&

		test_cmp before after
	)
'

test_expect_success 'expire removes repacked packs' '
	(
		cd dup &&
		ls -al .shit/objects/pack/*pack &&
		ls -S .shit/objects/pack/*pack | head -n 4 >expect &&
		shit multi-pack-index expire &&
		ls -S .shit/objects/pack/*pack >actual &&
		test_cmp expect actual &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 4 midx-list
	)
'

test_expect_success 'expire works when adding new packs' '
	(
		cd dup &&
		shit pack-objects --revs .shit/objects/pack/pack-combined <<-EOF &&
		refs/heads/A
		^refs/heads/B
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-combined <<-EOF &&
		refs/heads/B
		^refs/heads/C
		EOF
		shit pack-objects --revs .shit/objects/pack/pack-combined <<-EOF &&
		refs/heads/C
		^refs/heads/D
		EOF
		shit multi-pack-index write &&
		shit pack-objects --revs .shit/objects/pack/a-pack <<-EOF &&
		refs/heads/D
		^refs/heads/E
		EOF
		shit multi-pack-index write &&
		shit pack-objects --revs .shit/objects/pack/z-pack <<-EOF &&
		refs/heads/E
		EOF
		shit multi-pack-index expire &&
		ls .shit/objects/pack/ | grep idx >expect &&
		test-tool read-midx .shit/objects | grep idx >actual &&
		test_cmp expect actual &&
		shit multi-pack-index verify
	)
'

test_expect_success 'expire respects .keep files' '
	(
		cd dup &&
		shit pack-objects --revs .shit/objects/pack/pack-all <<-EOF &&
		refs/heads/A
		EOF
		shit multi-pack-index write &&
		PACKA=$(ls .shit/objects/pack/a-pack*\.pack | sed s/\.pack\$//) &&
		touch $PACKA.keep &&
		shit multi-pack-index expire &&
		test_path_is_file $PACKA.idx &&
		test_path_is_file $PACKA.keep &&
		test_path_is_file $PACKA.pack &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 2 midx-list
	)
'

test_expect_success 'expiring unreferenced cruft pack retains pack' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		test_commit base &&
		test_commit --no-tag unreachable &&
		unreachable=$(shit rev-parse HEAD) &&

		shit reset --hard base &&
		shit reflog expire --all --expire=all &&
		shit repack --cruft -d &&
		mtimes="$(ls $objdir/pack/pack-*.mtimes)" &&

		echo "base..$unreachable" >in &&
		pack="$(shit pack-objects --revs --delta-base-offset \
			$objdir/pack/pack <in)" &&

		# Preferring the contents of "$pack" will leave the
		# cruft pack unreferenced (ie., none of the objects
		# contained in the cruft pack will have their MIDX copy
		# selected from the cruft pack).
		shit multi-pack-index write --preferred-pack="pack-$pack.pack" &&
		shit multi-pack-index expire &&

		test_path_is_file "$mtimes"
	)
'

test_expect_success 'repack --batch-size=0 repacks everything' '
	cp -r dup dup2 &&
	(
		cd dup &&
		rm .shit/objects/pack/*.keep &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 2 idx-list &&
		shit multi-pack-index repack --batch-size=0 &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 3 idx-list &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 3 midx-list &&
		shit multi-pack-index expire &&
		ls -al .shit/objects/pack/*idx >idx-list &&
		test_line_count = 1 idx-list &&
		shit multi-pack-index repack --batch-size=0 &&
		ls -al .shit/objects/pack/*idx >new-idx-list &&
		test_cmp idx-list new-idx-list
	)
'

test_expect_success 'repack --batch-size=<large> repacks everything' '
	(
		cd dup2 &&
		rm .shit/objects/pack/*.keep &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 2 idx-list &&
		shit multi-pack-index repack --batch-size=2000000 &&
		ls .shit/objects/pack/*idx >idx-list &&
		test_line_count = 3 idx-list &&
		test-tool read-midx .shit/objects | grep idx >midx-list &&
		test_line_count = 3 midx-list &&
		shit multi-pack-index expire &&
		ls -al .shit/objects/pack/*idx >idx-list &&
		test_line_count = 1 idx-list
	)
'

test_expect_success 'load reverse index when missing .idx, .pack' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		shit config core.multiPackIndex true &&

		test_commit base &&
		shit repack -ad &&
		shit multi-pack-index write &&

		shit rev-parse HEAD >tip &&
		pack=$(ls .shit/objects/pack/pack-*.pack) &&
		idx=$(ls .shit/objects/pack/pack-*.idx) &&

		mv $idx $idx.bak &&
		shit cat-file --batch-check="%(objectsize:disk)" <tip &&

		mv $idx.bak $idx &&

		mv $pack $pack.bak &&
		shit cat-file --batch-check="%(objectsize:disk)" <tip
	)
'

test_expect_success 'usage shown without sub-command' '
	test_expect_code 129 shit multi-pack-index 2>err &&
	! test_grep "unrecognized subcommand" err
'

test_expect_success 'complains when run outside of a repository' '
	nonshit test_must_fail shit multi-pack-index write 2>err &&
	grep "not a shit repository" err
'

test_expect_success 'repack with delta islands' '
	shit init repo &&
	test_when_finished "rm -fr repo" &&
	(
		cd repo &&

		test_commit first &&
		shit repack &&
		test_commit second &&
		shit repack &&

		shit multi-pack-index write &&
		shit -c repack.useDeltaIslands=true multi-pack-index repack
	)
'

corrupt_chunk () {
	midx=.shit/objects/pack/multi-pack-index &&
	test_when_finished "rm -rf $midx" &&
	shit repack -ad --write-midx &&
	corrupt_chunk_file $midx "$@"
}

test_expect_success 'reader notices too-small oid fanout chunk' '
	corrupt_chunk OIDF clear 00000000 &&
	test_must_fail shit log 2>err &&
	cat >expect <<-\EOF &&
	error: multi-pack-index OID fanout is of the wrong size
	fatal: multi-pack-index required OID fanout chunk missing or corrupted
	EOF
	test_cmp expect err
'

test_expect_success 'reader notices too-small oid lookup chunk' '
	corrupt_chunk OIDL clear 00000000 &&
	test_must_fail shit log 2>err &&
	cat >expect <<-\EOF &&
	error: multi-pack-index OID lookup chunk is the wrong size
	fatal: multi-pack-index required OID lookup chunk missing or corrupted
	EOF
	test_cmp expect err
'

test_expect_success 'reader notices too-small pack names chunk' '
	# There is no NUL to terminate the name here, so the
	# chunk is too short.
	corrupt_chunk PNAM clear 70656666 &&
	test_must_fail shit log 2>err &&
	cat >expect <<-\EOF &&
	fatal: multi-pack-index pack-name chunk is too short
	EOF
	test_cmp expect err
'

test_expect_success 'reader handles unaligned chunks' '
	# A 9-byte PNAM means all of the subsequent chunks
	# will no longer be 4-byte aligned, but it is still
	# a valid one-pack chunk on its own (it is "foo.pack\0").
	corrupt_chunk PNAM clear 666f6f2e7061636b00 &&
	shit -c core.multipackindex=false log >expect.out &&
	shit -c core.multipackindex=true log >out 2>err &&
	test_cmp expect.out out &&
	cat >expect.err <<-\EOF &&
	error: chunk id 4f494446 not 4-byte aligned
	EOF
	test_cmp expect.err err
'

test_expect_success 'reader notices too-small object offset chunk' '
	corrupt_chunk OOFF clear 00000000 &&
	test_must_fail shit log 2>err &&
	cat >expect <<-\EOF &&
	error: multi-pack-index object offset chunk is the wrong size
	fatal: multi-pack-index required object offsets chunk missing or corrupted
	EOF
	test_cmp expect err
'

test_expect_success 'reader bounds-checks large offset table' '
	# re-use the objects64 dir here to cheaply get access to a midx
	# with large offsets.
	shit init repo &&
	test_when_finished "rm -rf repo" &&
	(
		cd repo &&
		(cd ../objects64 && pwd) >.shit/objects/info/alternates &&
		shit multi-pack-index --object-dir=../objects64 write &&
		midx=../objects64/pack/multi-pack-index &&
		corrupt_chunk_file $midx LOFF clear &&
		# using only %(objectsize) is important here; see the commit
		# message for more details
		test_must_fail shit cat-file --batch-all-objects \
			--batch-check="%(objectsize)" 2>err &&
		cat >expect <<-\EOF &&
		fatal: multi-pack-index large offset out of bounds
		EOF
		test_cmp expect err
	)
'

test_expect_success 'reader notices too-small revindex chunk' '
	# We only get a revindex with bitmaps (and likewise only
	# load it when they are asked for).
	test_config repack.writeBitmaps true &&
	corrupt_chunk RIDX clear 00000000 &&
	shit -c core.multipackIndex=false rev-list \
		--all --use-bitmap-index >expect.out &&
	shit -c core.multipackIndex=true rev-list \
		--all --use-bitmap-index >out 2>err &&
	test_cmp expect.out out &&
	cat >expect.err <<-\EOF &&
	error: multi-pack-index reverse-index chunk is the wrong size
	warning: multi-pack bitmap is missing required reverse index
	EOF
	test_cmp expect.err err
'

test_expect_success 'reader notices out-of-bounds fanout' '
	# This is similar to the out-of-bounds fanout test in t5318. The values
	# in adjacent entries should be large but not identical (they
	# are used as hi/lo starts for a binary search, which would then abort
	# immediately).
	corrupt_chunk OIDF 0 $(printf "%02x000000" $(test_seq 0 254)) &&
	test_must_fail shit log 2>err &&
	cat >expect <<-\EOF &&
	error: oid fanout out of order: fanout[254] = fe000000 > 5c = fanout[255]
	fatal: multi-pack-index required OID fanout chunk missing or corrupted
	EOF
	test_cmp expect err
'

test_expect_success 'bitmapped packs are stored via the BTMP chunk' '
	test_when_finished "rm -fr repo" &&
	shit init repo &&
	(
		cd repo &&

		for i in 1 2 3 4 5
		do
			test_commit "$i" &&
			shit repack -d || return 1
		done &&

		find $objdir/pack -type f -name "*.idx" | xargs -n 1 basename |
		sort >packs &&

		shit multi-pack-index write --stdin-packs <packs &&
		test_must_fail test-tool read-midx --bitmap $objdir 2>err &&
		cat >expect <<-\EOF &&
		error: MIDX does not contain the BTMP chunk
		EOF
		test_cmp expect err &&

		shit multi-pack-index write --stdin-packs --bitmap \
			--preferred-pack="$(head -n1 <packs)" <packs  &&
		test-tool read-midx --bitmap $objdir >actual &&
		for i in $(test_seq $(wc -l <packs))
		do
			sed -ne "${i}s/\.idx$/\.pack/p" packs &&
			echo "  bitmap_pos: $((($i - 1) * 3))" &&
			echo "  bitmap_nr: 3" || return 1
		done >expect &&
		test_cmp expect actual
	)
'

test_done
