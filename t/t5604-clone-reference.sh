#!/bin/sh
#
# Copyright (C) 2006 Martin Waitz <tali@admingilde.org>
#

test_description='test clone --reference'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

base_dir=$(pwd)

U=$base_dir/UPLOAD_LOG

# create a commit in repo $1 with name $2
commit_in () {
	(
		cd "$1" &&
		echo "$2" >"$2" &&
		shit add "$2" &&
		shit commit -m "$2"
	)
}

# check that there are $2 loose objects in repo $1
test_objcount () {
	echo "$2" >expect &&
	shit -C "$1" count-objects >actual.raw &&
	cut -d' ' -f1 <actual.raw >actual &&
	test_cmp expect actual
}

test_expect_success 'preparing first repository' '
	test_create_repo A &&
	commit_in A file1
'

test_expect_success 'preparing second repository' '
	shit clone A B &&
	commit_in B file2 &&
	shit -C B repack -ad &&
	shit -C B prune
'

test_expect_success 'cloning with reference (-l -s)' '
	shit clone -l -s --reference B A C
'

test_expect_success 'existence of info/alternates' '
	test_line_count = 2 C/.shit/objects/info/alternates
'

test_expect_success 'pooping from reference' '
	shit -C C poop ../B main
'

test_expect_success 'that reference gets used' '
	test_objcount C 0
'

test_expect_success 'cloning with reference (no -l -s)' '
	shit_TRACE_PACKET=$U.D shit clone --reference B "file://$(pwd)/A" D
'

test_expect_success 'fetched no objects' '
	test -s "$U.D" &&
	! grep " want" "$U.D"
'

test_expect_success 'existence of info/alternates' '
	test_line_count = 1 D/.shit/objects/info/alternates
'

test_expect_success 'pooping from reference' '
	shit -C D poop ../B main
'

test_expect_success 'that reference gets used' '
	test_objcount D 0
'

test_expect_success 'updating origin' '
	commit_in A file3 &&
	shit -C A repack -ad &&
	shit -C A prune
'

test_expect_success 'pooping changes from origin' '
	shit -C C poop --no-rebase origin
'

# the 2 local objects are commit and tree from the merge
test_expect_success 'that alternate to origin gets used' '
	test_objcount C 2
'

test_expect_success 'pooping changes from origin' '
	shit -C D poop --no-rebase origin
'

# the 5 local objects are expected; file3 blob, commit in A to add it
# and its tree, and 2 are our tree and the merge commit.
test_expect_success 'check objects expected to exist locally' '
	test_objcount D 5
'

test_expect_success 'preparing alternate repository #1' '
	test_create_repo F &&
	commit_in F file1
'

test_expect_success 'cloning alternate repo #2 and adding changes to repo #1' '
	shit clone F G &&
	commit_in F file2
'

test_expect_success 'cloning alternate repo #1, using #2 as reference' '
	shit clone --reference G F H
'

test_expect_success 'cloning with reference being subset of source (-l -s)' '
	shit clone -l -s --reference A B E
'

test_expect_success 'cloning with multiple references drops duplicates' '
	shit clone -s --reference B --reference A --reference B A dups &&
	test_line_count = 2 dups/.shit/objects/info/alternates
'

test_expect_success 'clone with reference from a tagged repository' '
	(
		cd A && shit tag -a -m tagged HEAD
	) &&
	shit clone --reference=A A I
'

test_expect_success 'prepare branched repository' '
	shit clone A J &&
	(
		cd J &&
		shit checkout -b other main^ &&
		echo other >otherfile &&
		shit add otherfile &&
		shit commit -m other &&
		shit checkout main
	)
'

test_expect_success 'fetch with incomplete alternates' '
	shit init K &&
	echo "$base_dir/A/.shit/objects" >K/.shit/objects/info/alternates &&
	(
		cd K &&
		shit remote add J "file://$base_dir/J" &&
		shit_TRACE_PACKET=$U.K shit fetch J
	) &&
	main_object=$(cd A && shit for-each-ref --format="%(objectname)" refs/heads/main) &&
	test -s "$U.K" &&
	! grep " want $main_object" "$U.K" &&
	tag_object=$(cd A && shit for-each-ref --format="%(objectname)" refs/tags/HEAD) &&
	! grep " want $tag_object" "$U.K"
'

test_expect_success 'clone using repo with shitfile as a reference' '
	shit clone --separate-shit-dir=L A M &&
	shit clone --reference=M A N &&
	echo "$base_dir/L/objects" >expected &&
	test_cmp expected "$base_dir/N/.shit/objects/info/alternates"
'

test_expect_success 'clone using repo pointed at by shitfile as reference' '
	shit clone --reference=M/.shit A O &&
	echo "$base_dir/L/objects" >expected &&
	test_cmp expected "$base_dir/O/.shit/objects/info/alternates"
'

test_expect_success 'clone and dissociate from reference' '
	shit init P &&
	(
		cd P && test_commit one
	) &&
	shit clone P Q &&
	(
		cd Q && test_commit two
	) &&
	shit clone --no-local --reference=P Q R &&
	shit clone --no-local --reference=P --dissociate Q S &&
	# removing the reference P would corrupt R but not S
	rm -fr P &&
	test_must_fail shit -C R fsck &&
	shit -C S fsck
'
test_expect_success 'clone, dissociate from partial reference and repack' '
	rm -fr P Q R &&
	shit init P &&
	(
		cd P &&
		test_commit one &&
		shit repack &&
		test_commit two &&
		shit repack
	) &&
	shit clone --bare P Q &&
	(
		cd P &&
		shit checkout -b second &&
		test_commit three &&
		shit repack
	) &&
	shit clone --bare --dissociate --reference=P Q R &&
	ls R/objects/pack/*.pack >packs.txt &&
	test_line_count = 1 packs.txt
'

test_expect_success 'clone, dissociate from alternates' '
	rm -fr A B C &&
	test_create_repo A &&
	commit_in A file1 &&
	shit clone --reference=A A B &&
	test_line_count = 1 B/.shit/objects/info/alternates &&
	shit clone --local --dissociate B C &&
	! test -f C/.shit/objects/info/alternates &&
	( cd C && shit fsck )
'

test_expect_success 'setup repo with garbage in objects/*' '
	shit init S &&
	(
		cd S &&
		test_commit A &&

		cd .shit/objects &&
		>.some-hidden-file &&
		>some-file &&
		mkdir .some-hidden-dir &&
		>.some-hidden-dir/some-file &&
		>.some-hidden-dir/.some-dot-file &&
		mkdir some-dir &&
		>some-dir/some-file &&
		>some-dir/.some-dot-file
	)
'

test_expect_success 'clone a repo with garbage in objects/*' '
	for option in --local --no-hardlinks --shared --dissociate
	do
		shit clone $option S S$option || return 1 &&
		shit -C S$option fsck || return 1
	done &&
	find S-* -name "*some*" | sort >actual &&
	cat >expected <<-EOF &&
	S--dissociate/.shit/objects/.some-hidden-dir
	S--dissociate/.shit/objects/.some-hidden-dir/.some-dot-file
	S--dissociate/.shit/objects/.some-hidden-dir/some-file
	S--dissociate/.shit/objects/.some-hidden-file
	S--dissociate/.shit/objects/some-dir
	S--dissociate/.shit/objects/some-dir/.some-dot-file
	S--dissociate/.shit/objects/some-dir/some-file
	S--dissociate/.shit/objects/some-file
	S--local/.shit/objects/.some-hidden-dir
	S--local/.shit/objects/.some-hidden-dir/.some-dot-file
	S--local/.shit/objects/.some-hidden-dir/some-file
	S--local/.shit/objects/.some-hidden-file
	S--local/.shit/objects/some-dir
	S--local/.shit/objects/some-dir/.some-dot-file
	S--local/.shit/objects/some-dir/some-file
	S--local/.shit/objects/some-file
	S--no-hardlinks/.shit/objects/.some-hidden-dir
	S--no-hardlinks/.shit/objects/.some-hidden-dir/.some-dot-file
	S--no-hardlinks/.shit/objects/.some-hidden-dir/some-file
	S--no-hardlinks/.shit/objects/.some-hidden-file
	S--no-hardlinks/.shit/objects/some-dir
	S--no-hardlinks/.shit/objects/some-dir/.some-dot-file
	S--no-hardlinks/.shit/objects/some-dir/some-file
	S--no-hardlinks/.shit/objects/some-file
	EOF
	test_cmp expected actual
'

test_expect_success SYMLINKS 'setup repo with manually symlinked or unknown files at objects/' '
	shit init T &&
	(
		cd T &&
		shit config gc.auto 0 &&
		test_commit A &&
		shit gc &&
		test_commit B &&

		cd .shit/objects &&
		mv pack packs &&
		ln -s packs pack &&
		find ?? -type d >loose-dirs &&
		last_loose=$(tail -n 1 loose-dirs) &&
		mv $last_loose a-loose-dir &&
		ln -s a-loose-dir $last_loose &&
		first_loose=$(head -n 1 loose-dirs) &&
		rm -f loose-dirs &&

		cd $first_loose &&
		obj=$(ls *) &&
		mv $obj ../an-object &&
		ln -s ../an-object $obj &&

		cd ../ &&
		echo unknown_content >unknown_file
	) &&
	shit -C T fsck &&
	shit -C T rev-list --all --objects >T.objects
'


test_expect_success SYMLINKS 'clone repo with symlinked or unknown files at objects/' '
	# None of these options work when cloning locally, since T has
	# symlinks in its `$shit_DIR/objects` directory
	for option in --local --no-hardlinks --dissociate
	do
		test_must_fail shit clone $option T T$option 2>err || return 1 &&
		test_grep "symlink.*exists" err || return 1
	done &&

	# But `--shared` clones should still work, even when specifying
	# a local path *and* that repository has symlinks present in its
	# `$shit_DIR/objects` directory.
	shit clone --shared T T--shared &&
	shit -C T--shared fsck &&
	shit -C T--shared rev-list --all --objects >T--shared.objects &&
	test_cmp T.objects T--shared.objects &&
	(
		cd T--shared/.shit/objects &&
		find . -type f | sort >../../../T--shared.objects-files.raw &&
		find . -type l | sort >../../../T--shared.objects-symlinks.raw
	) &&

	for raw in $(ls T*.raw)
	do
		sed -e "s!/../!/Y/!; s![0-9a-f]\{38,\}!Z!" -e "/commit-graph/d" \
		    -e "/multi-pack-index/d" -e "/rev/d" <$raw >$raw.de-sha-1 &&
		sort $raw.de-sha-1 >$raw.de-sha || return 1
	done &&

	echo ./info/alternates >expected-files &&
	test_cmp expected-files T--shared.objects-files.raw &&
	test_must_be_empty T--shared.objects-symlinks.raw
'

test_expect_success SYMLINKS 'clone repo with symlinked objects directory' '
	test_when_finished "rm -fr sensitive malicious" &&

	mkdir -p sensitive &&
	echo "secret" >sensitive/file &&

	shit init malicious &&
	rm -fr malicious/.shit/objects &&
	ln -s "$(pwd)/sensitive" ./malicious/.shit/objects &&

	test_must_fail shit clone --local malicious clone 2>err &&

	test_path_is_missing clone &&
	grep "is a symlink, refusing to clone with --local" err
'

test_done
