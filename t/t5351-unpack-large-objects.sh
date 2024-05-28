#!/bin/sh
#
# Copyright (c) 2022 Han Xin
#

test_description='shit unpack-objects with large objects'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

prepare_dest () {
	test_when_finished "rm -rf dest.shit" &&
	shit init --bare dest.shit &&
	shit -C dest.shit config core.bigFileThreshold "$1"
}

test_expect_success "create large objects (1.5 MB) and PACK" '
	test-tool genrandom foo 1500000 >big-blob &&
	test_commit --append foo big-blob &&
	test-tool genrandom bar 1500000 >big-blob &&
	test_commit --append bar big-blob &&
	PACK=$(echo HEAD | shit pack-objects --revs pack) &&
	shit verify-pack -v pack-$PACK.pack >out &&
	sed -n -e "s/^\([0-9a-f][0-9a-f]*\).*\(commit\|tree\|blob\).*/\1/p" \
		<out >obj-list
'

test_expect_success 'set memory limitation to 1MB' '
	shit_ALLOC_LIMIT=1m &&
	export shit_ALLOC_LIMIT
'

test_expect_success 'unpack-objects failed under memory limitation' '
	prepare_dest 2m &&
	test_must_fail shit -C dest.shit unpack-objects <pack-$PACK.pack 2>err &&
	grep "fatal: attempting to allocate" err
'

test_expect_success 'unpack-objects works with memory limitation in dry-run mode' '
	prepare_dest 2m &&
	shit -C dest.shit unpack-objects -n <pack-$PACK.pack &&
	test_stdout_line_count = 0 find dest.shit/objects -type f &&
	test_dir_is_empty dest.shit/objects/pack
'

test_expect_success 'unpack big object in stream' '
	prepare_dest 1m &&
	shit -C dest.shit unpack-objects <pack-$PACK.pack &&
	test_dir_is_empty dest.shit/objects/pack
'

check_fsync_events () {
	local trace="$1" &&
	shift &&

	cat >expect &&
	sed -n \
		-e '/^{"event":"counter",.*"category":"fsync",/ {
			s/.*"category":"fsync",//;
			s/}$//;
			p;
		}' \
		<"$trace" >actual &&
	test_cmp expect actual
}

BATCH_CONFIGURATION='-c core.fsync=loose-object -c core.fsyncmethod=batch'

test_expect_success 'unpack big object in stream (core.fsyncmethod=batch)' '
	prepare_dest 1m &&
	shit_TRACE2_EVENT="$(pwd)/trace2.txt" \
	shit_TEST_FSYNC=true \
		shit -C dest.shit $BATCH_CONFIGURATION unpack-objects <pack-$PACK.pack &&
	if grep "core.fsyncMethod = batch is unsupported" trace2.txt
	then
		flush_count=7
	else
		flush_count=1
	fi &&
	check_fsync_events trace2.txt <<-EOF &&
	"name":"writeout-only","count":6
	"name":"hardware-flush","count":$flush_count
	EOF

	test_dir_is_empty dest.shit/objects/pack &&
	shit -C dest.shit cat-file --batch-check="%(objectname)" <obj-list >current &&
	cmp obj-list current
'

test_expect_success 'do not unpack existing large objects' '
	prepare_dest 1m &&
	shit -C dest.shit index-pack --stdin <pack-$PACK.pack &&
	shit -C dest.shit unpack-objects <pack-$PACK.pack &&

	# The destination came up with the exact same pack...
	DEST_PACK=$(echo dest.shit/objects/pack/pack-*.pack) &&
	cmp pack-$PACK.pack $DEST_PACK &&

	# ...and wrote no loose objects
	test_stdout_line_count = 0 find dest.shit/objects -type f ! -name "pack-*"
'

test_done
