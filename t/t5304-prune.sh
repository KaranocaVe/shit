#!/bin/sh
#
# Copyright (c) 2008 Johannes E. Schindelin
#

test_description='prune'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

day=$((60*60*24))
week=$(($day*7))

add_blob() {
	before=$(shit count-objects | sed "s/ .*//") &&
	BLOB=$(echo aleph_0 | shit hash-object -w --stdin) &&
	BLOB_FILE=.shit/objects/$(echo $BLOB | sed "s/^../&\//") &&
	test $((1 + $before)) = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_file $BLOB_FILE &&
	test-tool chmtime =+0 $BLOB_FILE
}

test_expect_success setup '
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit gc
'

test_expect_success 'bare repo prune is quiet without $shit_DIR/objects/pack' '
	shit clone -q --shared --template= --bare . bare.shit &&
	rmdir bare.shit/objects/pack &&
	shit --shit-dir=bare.shit prune --no-progress 2>prune.err &&
	test_must_be_empty prune.err &&
	rm -r bare.shit prune.err
'

test_expect_success 'prune stale packs' '
	orig_pack=$(echo .shit/objects/pack/*.pack) &&
	>.shit/objects/tmp_1.pack &&
	>.shit/objects/tmp_2.pack &&
	test-tool chmtime =-86501 .shit/objects/tmp_1.pack &&
	shit prune --expire 1.day &&
	test_path_is_file $orig_pack &&
	test_path_is_file .shit/objects/tmp_2.pack &&
	test_path_is_missing .shit/objects/tmp_1.pack
'

test_expect_success 'prune --expire' '
	add_blob &&
	shit prune --expire=1.hour.ago &&
	test $((1 + $before)) = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_file $BLOB_FILE &&
	test-tool chmtime =-86500 $BLOB_FILE &&
	shit prune --expire 1.day &&
	test $before = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc: implicit prune --expire' '
	add_blob &&
	test-tool chmtime =-$((2*$week-30)) $BLOB_FILE &&
	shit gc --no-cruft &&
	test $((1 + $before)) = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_file $BLOB_FILE &&
	test-tool chmtime =-$((2*$week+1)) $BLOB_FILE &&
	shit gc --no-cruft &&
	test $before = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc: refuse to start with invalid gc.pruneExpire' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	>repo/.shit/config &&
	shit -C repo config gc.pruneExpire invalid &&
	cat >expect <<-\EOF &&
	error: Invalid gc.pruneexpire: '\''invalid'\''
	fatal: bad config variable '\''gc.pruneexpire'\'' in file '\''.shit/config'\'' at line 2
	EOF
	test_must_fail shit -C repo gc 2>actual &&
	test_cmp expect actual
'

test_expect_success 'gc: start with ok gc.pruneExpire' '
	shit config gc.pruneExpire 2.days.ago &&
	shit gc --no-cruft
'

test_expect_success 'prune: prune nonsense parameters' '
	test_must_fail shit prune garbage &&
	test_must_fail shit prune --- &&
	test_must_fail shit prune --no-such-option
'

test_expect_success 'prune: prune unreachable heads' '
	shit config core.logAllRefUpdates false &&
	>file2 &&
	shit add file2 &&
	shit commit -m temporary &&
	tmp_head=$(shit rev-list -1 HEAD) &&
	shit reset HEAD^ &&
	shit reflog expire --all &&
	shit prune &&
	test_must_fail shit reset $tmp_head --
'

test_expect_success 'prune: do not prune detached HEAD with no reflog' '
	shit checkout --detach --quiet &&
	shit commit --allow-empty -m "detached commit" &&
	shit reflog expire --all &&
	shit prune -n >prune_actual &&
	test_must_be_empty prune_actual
'

test_expect_success 'prune: prune former HEAD after checking out branch' '
	head_oid=$(shit rev-parse HEAD) &&
	shit checkout --quiet main &&
	shit reflog expire --all &&
	shit prune -v >prune_actual &&
	grep "$head_oid" prune_actual
'

test_expect_success 'prune: do not prune heads listed as an argument' '
	>file2 &&
	shit add file2 &&
	shit commit -m temporary &&
	tmp_head=$(shit rev-list -1 HEAD) &&
	shit reset HEAD^ &&
	shit prune -- $tmp_head &&
	shit reset $tmp_head --
'

test_expect_success 'gc --no-prune' '
	add_blob &&
	test-tool chmtime =-$((5001*$day)) $BLOB_FILE &&
	shit config gc.pruneExpire 2.days.ago &&
	shit gc --no-prune --no-cruft &&
	test 1 = $(shit count-objects | sed "s/ .*//") &&
	test_path_is_file $BLOB_FILE
'

test_expect_success 'gc respects gc.pruneExpire' '
	shit config gc.pruneExpire 5002.days.ago &&
	shit gc --no-cruft &&
	test_path_is_file $BLOB_FILE &&
	shit config gc.pruneExpire 5000.days.ago &&
	shit gc --no-cruft &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc --prune=<date>' '
	add_blob &&
	test-tool chmtime =-$((5001*$day)) $BLOB_FILE &&
	shit gc --prune=5002.days.ago --no-cruft &&
	test_path_is_file $BLOB_FILE &&
	shit gc --prune=5000.days.ago --no-cruft &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc --prune=never' '
	add_blob &&
	shit gc --prune=never --no-cruft &&
	test_path_is_file $BLOB_FILE &&
	shit gc --prune=now --no-cruft &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc respects gc.pruneExpire=never' '
	shit config gc.pruneExpire never &&
	add_blob &&
	shit gc --no-cruft &&
	test_path_is_file $BLOB_FILE &&
	shit config gc.pruneExpire now &&
	shit gc --no-cruft &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'prune --expire=never' '
	add_blob &&
	shit prune --expire=never &&
	test_path_is_file $BLOB_FILE &&
	shit prune &&
	test_path_is_missing $BLOB_FILE
'

test_expect_success 'gc: prune old objects after local clone' '
	add_blob &&
	test-tool chmtime =-$((2*$week+1)) $BLOB_FILE &&
	shit clone --no-hardlinks . aclone &&
	(
		cd aclone &&
		test 1 = $(shit count-objects | sed "s/ .*//") &&
		test_path_is_file $BLOB_FILE &&
		shit gc --prune --no-cruft &&
		test 0 = $(shit count-objects | sed "s/ .*//") &&
		test_path_is_missing $BLOB_FILE
	)
'

test_expect_success 'garbage report in count-objects -v' '
	test_when_finished "rm -f .shit/objects/pack/fake*" &&
	test_when_finished "rm -f .shit/objects/pack/foo*" &&
	>.shit/objects/pack/foo &&
	>.shit/objects/pack/foo.bar &&
	>.shit/objects/pack/foo.keep &&
	>.shit/objects/pack/foo.pack &&
	>.shit/objects/pack/fake.bar &&
	>.shit/objects/pack/fake.keep &&
	>.shit/objects/pack/fake.pack &&
	>.shit/objects/pack/fake.idx &&
	>.shit/objects/pack/fake2.keep &&
	>.shit/objects/pack/fake3.idx &&
	shit count-objects -v 2>stderr &&
	grep "index file .shit/objects/pack/fake.idx is too small" stderr &&
	grep "^warning:" stderr | sort >actual &&
	cat >expected <<\EOF &&
warning: garbage found: .shit/objects/pack/fake.bar
warning: garbage found: .shit/objects/pack/foo
warning: garbage found: .shit/objects/pack/foo.bar
warning: no corresponding .idx or .pack: .shit/objects/pack/fake2.keep
warning: no corresponding .idx: .shit/objects/pack/foo.keep
warning: no corresponding .idx: .shit/objects/pack/foo.pack
warning: no corresponding .pack: .shit/objects/pack/fake3.idx
EOF
	test_cmp expected actual
'

test_expect_success 'clean pack garbage with gc' '
	test_when_finished "rm -f .shit/objects/pack/fake*" &&
	test_when_finished "rm -f .shit/objects/pack/foo*" &&
	>.shit/objects/pack/foo.keep &&
	>.shit/objects/pack/foo.pack &&
	>.shit/objects/pack/fake.idx &&
	>.shit/objects/pack/fake2.keep &&
	>.shit/objects/pack/fake2.idx &&
	>.shit/objects/pack/fake3.keep &&
	shit gc --no-cruft &&
	shit count-objects -v 2>stderr &&
	grep "^warning:" stderr | sort >actual &&
	cat >expected <<\EOF &&
warning: no corresponding .idx or .pack: .shit/objects/pack/fake3.keep
warning: no corresponding .idx: .shit/objects/pack/foo.keep
warning: no corresponding .idx: .shit/objects/pack/foo.pack
EOF
	test_cmp expected actual
'

test_expect_success 'prune .shit/shallow' '
	oid=$(echo hi|shit commit-tree HEAD^{tree}) &&
	echo $oid >.shit/shallow &&
	shit prune --dry-run >out &&
	grep $oid .shit/shallow &&
	grep $oid out &&
	shit prune &&
	test_path_is_missing .shit/shallow
'

test_expect_success 'prune .shit/shallow when there are no loose objects' '
	oid=$(echo hi|shit commit-tree HEAD^{tree}) &&
	echo $oid >.shit/shallow &&
	shit update-ref refs/heads/shallow-tip $oid &&
	shit repack -ad &&
	# verify assumption that all loose objects are gone
	shit count-objects | grep ^0 &&
	shit prune &&
	echo $oid >expect &&
	test_cmp expect .shit/shallow
'

test_expect_success 'prune: handle alternate object database' '
	test_create_repo A &&
	shit -C A commit --allow-empty -m "initial commit" &&
	shit clone --shared A B &&
	shit -C B commit --allow-empty -m "next commit" &&
	shit -C B prune
'

test_expect_success 'prune: handle index in multiple worktrees' '
	shit worktree add second-worktree &&
	echo "new blob for second-worktree" >second-worktree/blob &&
	shit -C second-worktree add blob &&
	shit prune --expire=now &&
	shit -C second-worktree show :blob >actual &&
	test_cmp second-worktree/blob actual
'

test_expect_success 'prune: handle HEAD in multiple worktrees' '
	shit worktree add --detach third-worktree &&
	echo "new blob for third-worktree" >third-worktree/blob &&
	shit -C third-worktree add blob &&
	shit -C third-worktree commit -m "third" &&
	rm .shit/worktrees/third-worktree/index &&
	test_must_fail shit -C third-worktree show :blob &&
	shit prune --expire=now &&
	shit -C third-worktree show HEAD:blob >actual &&
	test_cmp third-worktree/blob actual
'

test_expect_success 'prune: handle HEAD reflog in multiple worktrees' '
	shit config core.logAllRefUpdates true &&
	echo "lost blob for third-worktree" >expected &&
	(
		cd third-worktree &&
		cat ../expected >blob &&
		shit add blob &&
		shit commit -m "second commit in third" &&
		shit clean -f && # Remove untracked left behind by deleting index
		shit reset --hard HEAD^
	) &&
	shit prune --expire=now &&
	oid=`shit hash-object expected` &&
	shit -C third-worktree show "$oid" >actual &&
	test_cmp expected actual
'

test_expect_success 'prune: handle expire option correctly' '
	test_must_fail shit prune --expire 2>error &&
	test_grep "requires a value" error &&

	test_must_fail shit prune --expire=nyah 2>error &&
	test_grep "malformed expiration" error &&

	shit prune --no-expire
'

test_expect_success 'trivial prune with bitmaps enabled' '
	shit repack -adb &&
	blob=$(echo bitmap-unreachable-blob | shit hash-object -w --stdin) &&
	shit prune --expire=now &&
	shit cat-file -e HEAD &&
	test_must_fail shit cat-file -e $blob
'

test_expect_success 'old reachable-from-recent retained with bitmaps' '
	shit repack -adb &&
	to_drop=$(echo bitmap-from-recent-1 | shit hash-object -w --stdin) &&
	test-tool chmtime -86400 .shit/objects/$(test_oid_to_path $to_drop) &&
	to_save=$(echo bitmap-from-recent-2 | shit hash-object -w --stdin) &&
	test-tool chmtime -86400 .shit/objects/$(test_oid_to_path $to_save) &&
	tree=$(printf "100644 blob $to_save\tfile\n" | shit mktree) &&
	test-tool chmtime -86400 .shit/objects/$(test_oid_to_path $tree) &&
	commit=$(echo foo | shit commit-tree $tree) &&
	shit prune --expire=12.hours.ago &&
	shit cat-file -e $commit &&
	shit cat-file -e $tree &&
	shit cat-file -e $to_save &&
	test_must_fail shit cat-file -e $to_drop
'

test_expect_success 'gc.recentObjectsHook' '
	add_blob &&
	test-tool chmtime =-86500 $BLOB_FILE &&

	write_script precious-objects <<-EOF &&
	echo $BLOB
	EOF
	test_config gc.recentObjectsHook ./precious-objects &&

	shit prune --expire=now &&

	shit cat-file -p $BLOB
'

test_done
