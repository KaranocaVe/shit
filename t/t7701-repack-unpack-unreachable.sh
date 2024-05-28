#!/bin/sh

test_description='shit repack works correctly'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

fsha1=
csha1=
tsha1=

test_expect_success '-A with -d option leaves unreachable objects unpacked' '
	echo content > file1 &&
	shit add . &&
	test_tick &&
	shit commit -m initial_commit &&
	# create a transient branch with unique content
	shit checkout -b transient_branch &&
	echo more content >> file1 &&
	# record the objects created in the database for file, commit, tree
	fsha1=$(shit hash-object file1) &&
	test_tick &&
	shit commit -a -m more_content &&
	csha1=$(shit rev-parse HEAD^{commit}) &&
	tsha1=$(shit rev-parse HEAD^{tree}) &&
	shit checkout main &&
	echo even more content >> file1 &&
	test_tick &&
	shit commit -a -m even_more_content &&
	# delete the transient branch
	shit branch -D transient_branch &&
	# pack the repo
	shit repack -A -d -l &&
	# verify objects are packed in repository
	test 3 = $(shit verify-pack -v -- .shit/objects/pack/*.idx |
		   grep -E "^($fsha1|$csha1|$tsha1) " |
		   sort | uniq | wc -l) &&
	shit show $fsha1 &&
	shit show $csha1 &&
	shit show $tsha1 &&
	# now expire the reflog, while keeping reachable ones but expiring
	# unreachables immediately
	test_tick &&
	sometimeago=$(( $test_tick - 10000 )) &&
	shit reflog expire --expire=$sometimeago --expire-unreachable=$test_tick --all &&
	# and repack
	shit repack -A -d -l &&
	# verify objects are retained unpacked
	test 0 = $(shit verify-pack -v -- .shit/objects/pack/*.idx |
		   grep -E "^($fsha1|$csha1|$tsha1) " |
		   sort | uniq | wc -l) &&
	shit show $fsha1 &&
	shit show $csha1 &&
	shit show $tsha1
'

compare_mtimes ()
{
	read tref &&
	while read t; do
		test "$tref" = "$t" || return 1
	done
}

test_expect_success '-A without -d option leaves unreachable objects packed' '
	fsha1path=$(echo "$fsha1" | sed -e "s|\(..\)|\1/|") &&
	fsha1path=".shit/objects/$fsha1path" &&
	csha1path=$(echo "$csha1" | sed -e "s|\(..\)|\1/|") &&
	csha1path=".shit/objects/$csha1path" &&
	tsha1path=$(echo "$tsha1" | sed -e "s|\(..\)|\1/|") &&
	tsha1path=".shit/objects/$tsha1path" &&
	shit branch transient_branch $csha1 &&
	shit repack -a -d -l &&
	test ! -f "$fsha1path" &&
	test ! -f "$csha1path" &&
	test ! -f "$tsha1path" &&
	test 1 = $(ls -1 .shit/objects/pack/pack-*.pack | wc -l) &&
	packfile=$(ls .shit/objects/pack/pack-*.pack) &&
	shit branch -D transient_branch &&
	test_tick &&
	shit repack -A -l &&
	test ! -f "$fsha1path" &&
	test ! -f "$csha1path" &&
	test ! -f "$tsha1path" &&
	shit show $fsha1 &&
	shit show $csha1 &&
	shit show $tsha1
'

test_expect_success 'unpacked objects receive timestamp of pack file' '
	tmppack=".shit/objects/pack/tmp_pack" &&
	ln "$packfile" "$tmppack" &&
	shit repack -A -l -d &&
	test-tool chmtime --get "$tmppack" "$fsha1path" "$csha1path" "$tsha1path" \
		> mtimes &&
	compare_mtimes < mtimes
'

test_expect_success 'do not bother loosening old objects' '
	obj1=$(echo one | shit hash-object -w --stdin) &&
	obj2=$(echo two | shit hash-object -w --stdin) &&
	pack1=$(echo $obj1 | shit pack-objects .shit/objects/pack/pack) &&
	pack2=$(echo $obj2 | shit pack-objects .shit/objects/pack/pack) &&
	shit prune-packed &&
	shit cat-file -p $obj1 &&
	shit cat-file -p $obj2 &&
	test-tool chmtime =-86400 .shit/objects/pack/pack-$pack2.pack &&
	shit repack -A -d --unpack-unreachable=1.hour.ago &&
	shit cat-file -p $obj1 &&
	test_must_fail shit cat-file -p $obj2
'

test_expect_success 'gc.recentObjectsHook' '
	obj1=$(echo one | shit hash-object -w --stdin) &&
	obj2=$(echo two | shit hash-object -w --stdin) &&
	obj3=$(echo three | shit hash-object -w --stdin) &&
	pack1=$(echo $obj1 | shit pack-objects .shit/objects/pack/pack) &&
	pack2=$(echo $obj2 | shit pack-objects .shit/objects/pack/pack) &&
	pack3=$(echo $obj3 | shit pack-objects .shit/objects/pack/pack) &&
	shit prune-packed &&

	shit cat-file -p $obj1 &&
	shit cat-file -p $obj2 &&
	shit cat-file -p $obj3 &&

	# make an unreachable annotated tag object to ensure we rescue objects
	# which are reachable from non-pruned unreachable objects
	obj2_tag="$(shit mktag <<-EOF
	object $obj2
	type blob
	tag obj2-tag
	tagger T A Gger <tagger@example.com> 1234567890 -0000
	EOF
	)" &&

	obj2_tag_pack="$(echo $obj2_tag | shit pack-objects .shit/objects/pack/pack)" &&
	shit prune-packed &&

	write_script precious-objects <<-EOF &&
	echo $obj2_tag
	EOF
	shit config gc.recentObjectsHook ./precious-objects &&

	test-tool chmtime =-86400 .shit/objects/pack/pack-$pack2.pack &&
	test-tool chmtime =-86400 .shit/objects/pack/pack-$pack3.pack &&
	test-tool chmtime =-86400 .shit/objects/pack/pack-$obj2_tag_pack.pack &&
	shit repack -A -d --unpack-unreachable=1.hour.ago &&

	shit cat-file -p $obj1 &&
	shit cat-file -p $obj2 &&
	shit cat-file -p $obj2_tag &&
	test_must_fail shit cat-file -p $obj3
'

test_expect_success 'keep packed objects found only in index' '
	echo my-unique-content >file &&
	shit add file &&
	shit commit -m "make it reachable" &&
	shit gc &&
	shit reset HEAD^ &&
	shit reflog expire --expire=now --all &&
	shit add file &&
	test-tool chmtime =-86400 .shit/objects/pack/* &&
	shit gc --prune=1.hour.ago &&
	shit cat-file blob :file
'

test_expect_success 'repack -k keeps unreachable packed objects' '
	# create packed-but-unreachable object
	sha1=$(echo unreachable-packed | shit hash-object -w --stdin) &&
	pack=$(echo $sha1 | shit pack-objects .shit/objects/pack/pack) &&
	shit prune-packed &&

	# -k should keep it
	shit repack -adk &&
	shit cat-file -p $sha1 &&

	# and double check that without -k it would have been removed
	shit repack -ad &&
	test_must_fail shit cat-file -p $sha1
'

test_expect_success 'repack -k packs unreachable loose objects' '
	# create loose unreachable object
	sha1=$(echo would-be-deleted-loose | shit hash-object -w --stdin) &&
	objpath=.shit/objects/$(echo $sha1 | sed "s,..,&/,") &&
	test_path_is_file $objpath &&

	# and confirm that the loose object goes away, but we can
	# still access it (ergo, it is packed)
	shit repack -adk &&
	test_path_is_missing $objpath &&
	shit cat-file -p $sha1
'

test_done
