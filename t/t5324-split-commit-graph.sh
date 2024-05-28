#!/bin/sh

test_description='split commit graph'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-chunk.sh

shit_TEST_COMMIT_GRAPH=0
shit_TEST_COMMIT_GRAPH_CHANGED_PATHS=0

test_expect_success 'setup repo' '
	shit init &&
	shit config core.commitGraph true &&
	shit config gc.writeCommitGraph false &&
	infodir=".shit/objects/info" &&
	graphdir="$infodir/commit-graphs" &&
	test_oid_cache <<-EOM
	shallow sha1:2132
	shallow sha256:2436

	base sha1:1408
	base sha256:1528

	oid_version sha1:1
	oid_version sha256:2
	EOM
'

graph_read_expect() {
	NUM_BASE=0
	if test ! -z $2
	then
		NUM_BASE=$2
	fi
	OPTIONS=
	if test -z "$3"
	then
		OPTIONS=" read_generation_data"
	fi
	cat >expect <<- EOF
	header: 43475048 1 $(test_oid oid_version) 4 $NUM_BASE
	num_commits: $1
	chunks: oid_fanout oid_lookup commit_metadata generation_data
	options:$OPTIONS
	EOF
	test-tool read-graph >output &&
	test_cmp expect output
}

test_expect_success POSIXPERM 'tweak umask for modebit tests' '
	umask 022
'

test_expect_success 'create commits and write commit-graph' '
	for i in $(test_seq 3)
	do
		test_commit $i &&
		shit branch commits/$i || return 1
	done &&
	shit commit-graph write --reachable &&
	test_path_is_file $infodir/commit-graph &&
	graph_read_expect 3
'

graph_shit_two_modes() {
	shit ${2:+ -C "$2"} -c core.commitGraph=true $1 >output &&
	shit ${2:+ -C "$2"} -c core.commitGraph=false $1 >expect &&
	test_cmp expect output
}

graph_shit_behavior() {
	MSG=$1
	BRANCH=$2
	COMPARE=$3
	DIR=$4
	test_expect_success "check normal shit operations: $MSG" '
		graph_shit_two_modes "log --oneline $BRANCH" "$DIR" &&
		graph_shit_two_modes "log --topo-order $BRANCH" "$DIR" &&
		graph_shit_two_modes "log --graph $COMPARE..$BRANCH" "$DIR" &&
		graph_shit_two_modes "branch -vv" "$DIR" &&
		graph_shit_two_modes "merge-base -a $BRANCH $COMPARE" "$DIR"
	'
}

graph_shit_behavior 'graph exists' commits/3 commits/1

verify_chain_files_exist() {
	for hash in $(cat $1/commit-graph-chain)
	do
		test_path_is_file $1/graph-$hash.graph || return 1
	done
}

test_expect_success 'add more commits, and write a new base graph' '
	shit reset --hard commits/1 &&
	for i in $(test_seq 4 5)
	do
		test_commit $i &&
		shit branch commits/$i || return 1
	done &&
	shit reset --hard commits/2 &&
	for i in $(test_seq 6 10)
	do
		test_commit $i &&
		shit branch commits/$i || return 1
	done &&
	shit reset --hard commits/2 &&
	shit merge commits/4 &&
	shit branch merge/1 &&
	shit reset --hard commits/4 &&
	shit merge commits/6 &&
	shit branch merge/2 &&
	shit commit-graph write --reachable &&
	graph_read_expect 12
'

test_expect_success 'fork and fail to base a chain on a commit-graph file' '
	test_when_finished rm -rf fork &&
	shit clone . fork &&
	(
		cd fork &&
		rm .shit/objects/info/commit-graph &&
		echo "$(pwd)/../.shit/objects" >.shit/objects/info/alternates &&
		test_commit new-commit &&
		shit commit-graph write --reachable --split &&
		test_path_is_file $graphdir/commit-graph-chain &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		verify_chain_files_exist $graphdir
	)
'

test_expect_success 'add three more commits, write a tip graph' '
	shit reset --hard commits/3 &&
	shit merge merge/1 &&
	shit merge commits/5 &&
	shit merge merge/2 &&
	shit branch merge/3 &&
	shit commit-graph write --reachable --split &&
	test_path_is_missing $infodir/commit-graph &&
	test_path_is_file $graphdir/commit-graph-chain &&
	ls $graphdir/graph-*.graph >graph-files &&
	test_line_count = 2 graph-files &&
	verify_chain_files_exist $graphdir
'

graph_shit_behavior 'split commit-graph: merge 3 vs 2' merge/3 merge/2

test_expect_success 'add one commit, write a tip graph' '
	test_commit 11 &&
	shit branch commits/11 &&
	shit commit-graph write --reachable --split &&
	test_path_is_missing $infodir/commit-graph &&
	test_path_is_file $graphdir/commit-graph-chain &&
	ls $graphdir/graph-*.graph >graph-files &&
	test_line_count = 3 graph-files &&
	verify_chain_files_exist $graphdir
'

graph_shit_behavior 'three-layer commit-graph: commit 11 vs 6' commits/11 commits/6

test_expect_success 'add one commit, write a merged graph' '
	test_commit 12 &&
	shit branch commits/12 &&
	shit commit-graph write --reachable --split &&
	test_path_is_file $graphdir/commit-graph-chain &&
	test_line_count = 2 $graphdir/commit-graph-chain &&
	ls $graphdir/graph-*.graph >graph-files &&
	test_line_count = 2 graph-files &&
	verify_chain_files_exist $graphdir
'

graph_shit_behavior 'merged commit-graph: commit 12 vs 6' commits/12 commits/6

test_expect_success 'create fork and chain across alternate' '
	shit clone . fork &&
	(
		cd fork &&
		shit config core.commitGraph true &&
		rm -rf $graphdir &&
		echo "$(pwd)/../.shit/objects" >.shit/objects/info/alternates &&
		test_commit 13 &&
		shit branch commits/13 &&
		shit commit-graph write --reachable --split &&
		test_path_is_file $graphdir/commit-graph-chain &&
		test_line_count = 3 $graphdir/commit-graph-chain &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 1 graph-files &&
		shit -c core.commitGraph=true  rev-list HEAD >expect &&
		shit -c core.commitGraph=false rev-list HEAD >actual &&
		test_cmp expect actual &&
		test_commit 14 &&
		shit commit-graph write --reachable --split --object-dir=.shit/objects/ &&
		test_line_count = 3 $graphdir/commit-graph-chain &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 1 graph-files
	)
'

if test -d fork
then
	graph_shit_behavior 'alternate: commit 13 vs 6' commits/13 origin/commits/6 "fork"
fi

test_expect_success 'test merge stragety constants' '
	shit clone . merge-2 &&
	(
		cd merge-2 &&
		shit config core.commitGraph true &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test_commit 14 &&
		shit commit-graph write --reachable --split --size-multiple=2 &&
		test_line_count = 3 $graphdir/commit-graph-chain

	) &&
	shit clone . merge-10 &&
	(
		cd merge-10 &&
		shit config core.commitGraph true &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test_commit 14 &&
		shit commit-graph write --reachable --split --size-multiple=10 &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 1 graph-files
	) &&
	shit clone . merge-10-expire &&
	(
		cd merge-10-expire &&
		shit config core.commitGraph true &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test_commit 15 &&
		touch $graphdir/to-delete.graph $graphdir/to-keep.graph &&
		test-tool chmtime =1546362000 $graphdir/to-delete.graph &&
		test-tool chmtime =1546362001 $graphdir/to-keep.graph &&
		shit commit-graph write --reachable --split --size-multiple=10 \
			--expire-time="2019-01-01 12:00 -05:00" &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		test_path_is_missing $graphdir/to-delete.graph &&
		test_path_is_file $graphdir/to-keep.graph &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 3 graph-files
	) &&
	shit clone --no-hardlinks . max-commits &&
	(
		cd max-commits &&
		shit config core.commitGraph true &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test_commit 16 &&
		test_commit 17 &&
		shit commit-graph write --reachable --split --max-commits=1 &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 1 graph-files
	)
'

test_expect_success 'remove commit-graph-chain file after flattening' '
	shit clone . flatten &&
	(
		cd flatten &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		shit commit-graph write --reachable &&
		test_path_is_missing $graphdir/commit-graph-chain &&
		ls $graphdir >graph-files &&
		test_line_count = 0 graph-files
	)
'

corrupt_file() {
	file=$1
	pos=$2
	data="${3:-\0}"
	chmod a+w "$file" &&
	printf "$data" | dd of="$file" bs=1 seek="$pos" conv=notrunc
}

test_expect_success 'verify hashes along chain, even in shallow' '
	shit clone --no-hardlinks . verify &&
	(
		cd verify &&
		shit commit-graph verify &&
		base_file=$graphdir/graph-$(head -n 1 $graphdir/commit-graph-chain).graph &&
		corrupt_file "$base_file" $(test_oid shallow) "\01" &&
		test_must_fail shit commit-graph verify --shallow 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "incorrect checksum" err
	)
'

test_expect_success 'verify notices chain slice which is bogus (base)' '
	shit clone --no-hardlinks . verify-chain-bogus-base &&
	(
		cd verify-chain-bogus-base &&
		shit commit-graph verify &&
		base_file=$graphdir/graph-$(sed -n 1p $graphdir/commit-graph-chain).graph &&
		echo "garbage" >$base_file &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		grep "commit-graph file is too small" err
	)
'

test_expect_success 'verify notices chain slice which is bogus (tip)' '
	shit clone --no-hardlinks . verify-chain-bogus-tip &&
	(
		cd verify-chain-bogus-tip &&
		shit commit-graph verify &&
		tip_file=$graphdir/graph-$(sed -n 2p $graphdir/commit-graph-chain).graph &&
		echo "garbage" >$tip_file &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		grep "commit-graph file is too small" err
	)
'

test_expect_success 'verify --shallow does not check base contents' '
	shit clone --no-hardlinks . verify-shallow &&
	(
		cd verify-shallow &&
		shit commit-graph verify &&
		base_file=$graphdir/graph-$(head -n 1 $graphdir/commit-graph-chain).graph &&
		corrupt_file "$base_file" 1500 "\01" &&
		shit commit-graph verify --shallow &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "incorrect checksum" err
	)
'

test_expect_success 'warn on base graph chunk incorrect' '
	shit clone --no-hardlinks . base-chunk &&
	(
		cd base-chunk &&
		shit commit-graph verify &&
		base_file=$graphdir/graph-$(tail -n 1 $graphdir/commit-graph-chain).graph &&
		corrupt_file "$base_file" $(test_oid base) "\01" &&
		test_must_fail shit commit-graph verify --shallow 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "commit-graph chain does not match" err
	)
'

test_expect_success 'verify after commit-graph-chain corruption (base)' '
	shit clone --no-hardlinks . verify-chain-base &&
	(
		cd verify-chain-base &&
		corrupt_file "$graphdir/commit-graph-chain" 30 "G" &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "invalid commit-graph chain" err &&
		corrupt_file "$graphdir/commit-graph-chain" 30 "A" &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "unable to find all commit-graph files" err
	)
'

test_expect_success 'verify after commit-graph-chain corruption (tip)' '
	shit clone --no-hardlinks . verify-chain-tip &&
	(
		cd verify-chain-tip &&
		corrupt_file "$graphdir/commit-graph-chain" 70 "G" &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "invalid commit-graph chain" err &&
		corrupt_file "$graphdir/commit-graph-chain" 70 "A" &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "unable to find all commit-graph files" err
	)
'

test_expect_success 'verify notices too-short chain file' '
	shit clone --no-hardlinks . verify-chain-short &&
	(
		cd verify-chain-short &&
		shit commit-graph verify &&
		echo "garbage" >$graphdir/commit-graph-chain &&
		test_must_fail shit commit-graph verify 2>test_err &&
		grep -v "^+" test_err >err &&
		grep "commit-graph chain file too small" err
	)
'

test_expect_success 'verify across alternates' '
	shit clone --no-hardlinks . verify-alt &&
	(
		cd verify-alt &&
		rm -rf $graphdir &&
		altdir="$(pwd)/../.shit/objects" &&
		echo "$altdir" >.shit/objects/info/alternates &&
		shit commit-graph verify --object-dir="$altdir/" &&
		test_commit extra &&
		shit commit-graph write --reachable --split &&
		tip_file=$graphdir/graph-$(tail -n 1 $graphdir/commit-graph-chain).graph &&
		corrupt_file "$tip_file" 1500 "\01" &&
		test_must_fail shit commit-graph verify --shallow 2>test_err &&
		grep -v "^+" test_err >err &&
		test_grep "incorrect checksum" err
	)
'

test_expect_success 'reader bounds-checks base-graph chunk' '
	shit clone --no-hardlinks . corrupt-base-chunk &&
	(
		cd corrupt-base-chunk &&
		tip_file=$graphdir/graph-$(tail -n 1 $graphdir/commit-graph-chain).graph &&
		corrupt_chunk_file "$tip_file" BASE clear 01020304 &&
		shit -c core.commitGraph=false log >expect.out &&
		shit -c core.commitGraph=true log >out 2>err &&
		test_cmp expect.out out &&
		grep "commit-graph base graphs chunk is too small" err
	)
'

test_expect_success 'add octopus merge' '
	shit reset --hard commits/10 &&
	shit merge commits/3 commits/4 &&
	shit branch merge/octopus &&
	shit commit-graph write --reachable --split &&
	shit commit-graph verify --progress 2>err &&
	test_line_count = 1 err &&
	grep "Verifying commits in commit graph: 100% (18/18)" err &&
	test_grep ! warning err &&
	test_line_count = 3 $graphdir/commit-graph-chain
'

graph_shit_behavior 'graph exists' merge/octopus commits/12

test_expect_success 'split across alternate where alternate is not split' '
	shit commit-graph write --reachable &&
	test_path_is_file .shit/objects/info/commit-graph &&
	cp .shit/objects/info/commit-graph . &&
	shit clone --no-hardlinks . alt-split &&
	(
		cd alt-split &&
		rm -f .shit/objects/info/commit-graph &&
		echo "$(pwd)"/../.shit/objects >.shit/objects/info/alternates &&
		test_commit 18 &&
		shit commit-graph write --reachable --split &&
		test_line_count = 1 $graphdir/commit-graph-chain
	) &&
	test_cmp commit-graph .shit/objects/info/commit-graph
'

test_expect_success '--split=no-merge always writes an incremental' '
	test_when_finished rm -rf a b &&
	rm -rf $graphdir $infodir/commit-graph &&
	shit reset --hard commits/2 &&
	shit rev-list HEAD~1 >a &&
	shit rev-list HEAD >b &&
	shit commit-graph write --split --stdin-commits <a &&
	shit commit-graph write --split=no-merge --stdin-commits <b &&
	test_line_count = 2 $graphdir/commit-graph-chain
'

test_expect_success '--split=replace replaces the chain' '
	rm -rf $graphdir $infodir/commit-graph &&
	shit reset --hard commits/3 &&
	shit rev-list -1 HEAD~2 >a &&
	shit rev-list -1 HEAD~1 >b &&
	shit rev-list -1 HEAD >c &&
	shit commit-graph write --split=no-merge --stdin-commits <a &&
	shit commit-graph write --split=no-merge --stdin-commits <b &&
	shit commit-graph write --split=no-merge --stdin-commits <c &&
	test_line_count = 3 $graphdir/commit-graph-chain &&
	shit commit-graph write --stdin-commits --split=replace <b &&
	test_path_is_missing $infodir/commit-graph &&
	test_path_is_file $graphdir/commit-graph-chain &&
	ls $graphdir/graph-*.graph >graph-files &&
	test_line_count = 1 graph-files &&
	verify_chain_files_exist $graphdir &&
	graph_read_expect 2
'

test_expect_success ULIMIT_FILE_DESCRIPTORS 'handles file descriptor exhaustion' '
	shit init ulimit &&
	(
		cd ulimit &&
		for i in $(test_seq 64)
		do
			test_commit $i &&
			run_with_limited_open_files test_might_fail shit commit-graph write \
				--split=no-merge --reachable || return 1
		done
	)
'

while read mode modebits
do
	test_expect_success POSIXPERM "split commit-graph respects core.sharedrepository $mode" '
		rm -rf $graphdir $infodir/commit-graph &&
		shit reset --hard commits/1 &&
		test_config core.sharedrepository "$mode" &&
		shit commit-graph write --split --reachable &&
		ls $graphdir/graph-*.graph >graph-files &&
		test_line_count = 1 graph-files &&
		echo "$modebits" >expect &&
		test_modebits $graphdir/graph-*.graph >actual &&
		test_cmp expect actual &&
		test_modebits $graphdir/commit-graph-chain >actual &&
		test_cmp expect actual
	'
done <<\EOF
0666 -r--r--r--
0600 -r--------
EOF

test_expect_success '--split=replace with partial Bloom data' '
	rm -rf $graphdir $infodir/commit-graph &&
	shit reset --hard commits/3 &&
	shit rev-list -1 HEAD~2 >a &&
	shit rev-list -1 HEAD~1 >b &&
	shit commit-graph write --split=no-merge --stdin-commits --changed-paths <a &&
	shit commit-graph write --split=no-merge --stdin-commits <b &&
	shit commit-graph write --split=replace --stdin-commits --changed-paths <c &&
	ls $graphdir/graph-*.graph >graph-files &&
	test_line_count = 1 graph-files &&
	verify_chain_files_exist $graphdir
'

test_expect_success 'prevent regression for duplicate commits across layers' '
	shit init dup &&
	shit -C dup commit --allow-empty -m one &&
	shit -C dup -c core.commitGraph=false commit-graph write --split=no-merge --reachable 2>err &&
	test_grep "attempting to write a commit-graph" err &&
	shit -C dup commit-graph write --split=no-merge --reachable &&
	shit -C dup commit --allow-empty -m two &&
	shit -C dup commit-graph write --split=no-merge --reachable &&
	shit -C dup commit --allow-empty -m three &&
	shit -C dup commit-graph write --split --reachable &&
	shit -C dup commit-graph verify
'

NUM_FIRST_LAYER_COMMITS=64
NUM_SECOND_LAYER_COMMITS=16
NUM_THIRD_LAYER_COMMITS=7
NUM_FOURTH_LAYER_COMMITS=8
NUM_FIFTH_LAYER_COMMITS=16
SECOND_LAYER_SEQUENCE_START=$(($NUM_FIRST_LAYER_COMMITS + 1))
SECOND_LAYER_SEQUENCE_END=$(($SECOND_LAYER_SEQUENCE_START + $NUM_SECOND_LAYER_COMMITS - 1))
THIRD_LAYER_SEQUENCE_START=$(($SECOND_LAYER_SEQUENCE_END + 1))
THIRD_LAYER_SEQUENCE_END=$(($THIRD_LAYER_SEQUENCE_START + $NUM_THIRD_LAYER_COMMITS - 1))
FOURTH_LAYER_SEQUENCE_START=$(($THIRD_LAYER_SEQUENCE_END + 1))
FOURTH_LAYER_SEQUENCE_END=$(($FOURTH_LAYER_SEQUENCE_START + $NUM_FOURTH_LAYER_COMMITS - 1))
FIFTH_LAYER_SEQUENCE_START=$(($FOURTH_LAYER_SEQUENCE_END + 1))
FIFTH_LAYER_SEQUENCE_END=$(($FIFTH_LAYER_SEQUENCE_START + $NUM_FIFTH_LAYER_COMMITS - 1))

# Current split graph chain:
#
#     16 commits (No GDAT)
# ------------------------
#     64 commits (GDAT)
#
test_expect_success 'setup repo for mixed generation commit-graph-chain' '
	graphdir=".shit/objects/info/commit-graphs" &&
	test_oid_cache <<-EOF &&
	oid_version sha1:1
	oid_version sha256:2
	EOF
	shit init mixed &&
	(
		cd mixed &&
		shit config core.commitGraph true &&
		shit config gc.writeCommitGraph false &&
		for i in $(test_seq $NUM_FIRST_LAYER_COMMITS)
		do
			test_commit $i &&
			shit branch commits/$i || return 1
		done &&
		shit -c commitGraph.generationVersion=2 commit-graph write --reachable --split &&
		graph_read_expect $NUM_FIRST_LAYER_COMMITS &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		for i in $(test_seq $SECOND_LAYER_SEQUENCE_START $SECOND_LAYER_SEQUENCE_END)
		do
			test_commit $i &&
			shit branch commits/$i || return 1
		done &&
		shit -c commitGraph.generationVersion=1 commit-graph write --reachable --split=no-merge &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test-tool read-graph >output &&
		cat >expect <<-EOF &&
		header: 43475048 1 $(test_oid oid_version) 4 1
		num_commits: $NUM_SECOND_LAYER_COMMITS
		chunks: oid_fanout oid_lookup commit_metadata
		options:
		EOF
		test_cmp expect output &&
		shit commit-graph verify &&
		cat $graphdir/commit-graph-chain
	)
'

# The new layer will be added without generation data chunk as it was not
# present on the layer underneath it.
#
#      7 commits (No GDAT)
# ------------------------
#     16 commits (No GDAT)
# ------------------------
#     64 commits (GDAT)
#
test_expect_success 'do not write generation data chunk if not present on existing tip' '
	shit clone mixed mixed-no-gdat &&
	(
		cd mixed-no-gdat &&
		for i in $(test_seq $THIRD_LAYER_SEQUENCE_START $THIRD_LAYER_SEQUENCE_END)
		do
			test_commit $i &&
			shit branch commits/$i || return 1
		done &&
		shit commit-graph write --reachable --split=no-merge &&
		test_line_count = 3 $graphdir/commit-graph-chain &&
		test-tool read-graph >output &&
		cat >expect <<-EOF &&
		header: 43475048 1 $(test_oid oid_version) 4 2
		num_commits: $NUM_THIRD_LAYER_COMMITS
		chunks: oid_fanout oid_lookup commit_metadata
		options:
		EOF
		test_cmp expect output &&
		shit commit-graph verify
	)
'

# Number of commits in each layer of the split-commit graph before merge:
#
#      8 commits (No GDAT)
# ------------------------
#      7 commits (No GDAT)
# ------------------------
#     16 commits (No GDAT)
# ------------------------
#     64 commits (GDAT)
#
# The top two layers are merged and do not have generation data chunk as layer below them does
# not have generation data chunk.
#
#     15 commits (No GDAT)
# ------------------------
#     16 commits (No GDAT)
# ------------------------
#     64 commits (GDAT)
#
test_expect_success 'do not write generation data chunk if the topmost remaining layer does not have generation data chunk' '
	shit clone mixed-no-gdat mixed-merge-no-gdat &&
	(
		cd mixed-merge-no-gdat &&
		for i in $(test_seq $FOURTH_LAYER_SEQUENCE_START $FOURTH_LAYER_SEQUENCE_END)
		do
			test_commit $i &&
			shit branch commits/$i || return 1
		done &&
		shit commit-graph write --reachable --split --size-multiple 1 &&
		test_line_count = 3 $graphdir/commit-graph-chain &&
		test-tool read-graph >output &&
		cat >expect <<-EOF &&
		header: 43475048 1 $(test_oid oid_version) 4 2
		num_commits: $(($NUM_THIRD_LAYER_COMMITS + $NUM_FOURTH_LAYER_COMMITS))
		chunks: oid_fanout oid_lookup commit_metadata
		options:
		EOF
		test_cmp expect output &&
		shit commit-graph verify
	)
'

# Number of commits in each layer of the split-commit graph before merge:
#
#     16 commits (No GDAT)
# ------------------------
#     15 commits (No GDAT)
# ------------------------
#     16 commits (No GDAT)
# ------------------------
#     64 commits (GDAT)
#
# The top three layers are merged and has generation data chunk as the topmost remaining layer
# has generation data chunk.
#
#     47 commits (GDAT)
# ------------------------
#     64 commits (GDAT)
#
test_expect_success 'write generation data chunk if topmost remaining layer has generation data chunk' '
	shit clone mixed-merge-no-gdat mixed-merge-gdat &&
	(
		cd mixed-merge-gdat &&
		for i in $(test_seq $FIFTH_LAYER_SEQUENCE_START $FIFTH_LAYER_SEQUENCE_END)
		do
			test_commit $i &&
			shit branch commits/$i || return 1
		done &&
		shit commit-graph write --reachable --split --size-multiple 1 &&
		test_line_count = 2 $graphdir/commit-graph-chain &&
		test-tool read-graph >output &&
		cat >expect <<-EOF &&
		header: 43475048 1 $(test_oid oid_version) 5 1
		num_commits: $(($NUM_SECOND_LAYER_COMMITS + $NUM_THIRD_LAYER_COMMITS + $NUM_FOURTH_LAYER_COMMITS + $NUM_FIFTH_LAYER_COMMITS))
		chunks: oid_fanout oid_lookup commit_metadata generation_data
		options: read_generation_data
		EOF
		test_cmp expect output
	)
'

test_expect_success 'write generation data chunk when commit-graph chain is replaced' '
	shit clone mixed mixed-replace &&
	(
		cd mixed-replace &&
		shit commit-graph write --reachable --split=replace &&
		test_path_is_file $graphdir/commit-graph-chain &&
		test_line_count = 1 $graphdir/commit-graph-chain &&
		verify_chain_files_exist $graphdir &&
		graph_read_expect $(($NUM_FIRST_LAYER_COMMITS + $NUM_SECOND_LAYER_COMMITS)) &&
		shit commit-graph verify
	)
'

test_done
