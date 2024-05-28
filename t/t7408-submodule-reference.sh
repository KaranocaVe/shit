#!/bin/sh
#
# Copyright (c) 2009, Red Hat Inc, Author: Michael S. Tsirkin (mst@redhat.com)
#

test_description='test clone --reference'
. ./test-lib.sh

base_dir=$(pwd)

test_alternate_is_used () {
	alternates_file="$1" &&
	working_dir="$2" &&
	test_line_count = 1 "$alternates_file" &&
	echo "0 objects, 0 kilobytes" >expect &&
	shit -C "$working_dir" count-objects >actual &&
	test_cmp expect actual
}

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'preparing first repository' '
	test_create_repo A &&
	(
		cd A &&
		echo first >file1 &&
		shit add file1 &&
		shit commit -m A-initial
	)
'

test_expect_success 'preparing second repository' '
	shit clone A B &&
	(
		cd B &&
		echo second >file2 &&
		shit add file2 &&
		shit commit -m B-addition &&
		shit repack -a -d &&
		shit prune
	)
'

test_expect_success 'preparing superproject' '
	test_create_repo super &&
	(
		cd super &&
		echo file >file &&
		shit add file &&
		shit commit -m B-super-initial
	)
'

test_expect_success 'submodule add --reference uses alternates' '
	(
		cd super &&
		shit submodule add --reference ../B "file://$base_dir/A" sub &&
		shit commit -m B-super-added &&
		shit repack -ad
	) &&
	test_alternate_is_used super/.shit/modules/sub/objects/info/alternates super/sub
'

test_expect_success 'submodule add --reference with --dissociate does not use alternates' '
	(
		cd super &&
		shit submodule add --reference ../B --dissociate "file://$base_dir/A" sub-dissociate &&
		shit commit -m B-super-added &&
		shit repack -ad
	) &&
	test_path_is_missing super/.shit/modules/sub-dissociate/objects/info/alternates
'

test_expect_success 'that reference gets used with add' '
	(
		cd super/sub &&
		echo "0 objects, 0 kilobytes" >expected &&
		shit count-objects >current &&
		diff expected current
	)
'

# The tests up to this point, and repositories created by them
# (A, B, super and super/sub), are about setting up the stage
# for subsequent tests and meant to be kept throughout the
# remainder of the test.
# Tests from here on, if they create their own test repository,
# are expected to clean after themselves.

test_expect_success 'updating superproject keeps alternates' '
	test_when_finished "rm -rf super-clone" &&
	shit clone super super-clone &&
	shit -C super-clone submodule update --init --reference ../B &&
	test_alternate_is_used super-clone/.shit/modules/sub/objects/info/alternates super-clone/sub
'

test_expect_success 'updating superproject with --dissociate does not keep alternates' '
	test_when_finished "rm -rf super-clone" &&
	shit clone super super-clone &&
	shit -C super-clone submodule update --init --reference ../B --dissociate &&
	test_path_is_missing super-clone/.shit/modules/sub/objects/info/alternates
'

test_expect_success 'submodules use alternates when cloning a superproject' '
	test_when_finished "rm -rf super-clone" &&
	shit clone --reference super --recursive super super-clone &&
	(
		cd super-clone &&
		# test superproject has alternates setup correctly
		test_alternate_is_used .shit/objects/info/alternates . &&
		# test submodule has correct setup
		test_alternate_is_used .shit/modules/sub/objects/info/alternates sub
	)
'

test_expect_success 'missing submodule alternate fails clone and submodule update' '
	test_when_finished "rm -rf super-clone" &&
	shit clone super super2 &&
	test_must_fail shit clone --recursive --reference super2 super2 super-clone &&
	(
		cd super-clone &&
		# test superproject has alternates setup correctly
		test_alternate_is_used .shit/objects/info/alternates . &&
		# update of the submodule succeeds
		test_must_fail shit submodule update --init &&
		# and we have no alternates:
		test_path_is_missing .shit/modules/sub/objects/info/alternates &&
		test_path_is_missing sub/file1
	)
'

test_expect_success 'ignoring missing submodule alternates passes clone and submodule update' '
	test_when_finished "rm -rf super-clone" &&
	shit clone --reference-if-able super2 --recursive super2 super-clone &&
	(
		cd super-clone &&
		# test superproject has alternates setup correctly
		test_alternate_is_used .shit/objects/info/alternates . &&
		# update of the submodule succeeds
		shit submodule update --init &&
		# and we have no alternates:
		test_path_is_missing .shit/modules/sub/objects/info/alternates &&
		test_path_is_file sub/file1
	)
'

test_expect_success 'preparing second superproject with a nested submodule plus partial clone' '
	test_create_repo supersuper &&
	(
		cd supersuper &&
		echo "I am super super." >file &&
		shit add file &&
		shit commit -m B-super-super-initial &&
		shit submodule add "file://$base_dir/super" subwithsub &&
		shit commit -m B-super-super-added &&
		shit submodule update --init --recursive &&
		shit repack -ad
	) &&
	shit clone supersuper supersuper2 &&
	(
		cd supersuper2 &&
		shit submodule update --init
	)
'

# At this point there are three root-level positories: A, B, super and super2

test_expect_success 'nested submodule alternate in works and is actually used' '
	test_when_finished "rm -rf supersuper-clone" &&
	shit clone --recursive --reference supersuper supersuper supersuper-clone &&
	(
		cd supersuper-clone &&
		# test superproject has alternates setup correctly
		test_alternate_is_used .shit/objects/info/alternates . &&
		# immediate submodule has alternate:
		test_alternate_is_used .shit/modules/subwithsub/objects/info/alternates subwithsub &&
		# nested submodule also has alternate:
		test_alternate_is_used .shit/modules/subwithsub/modules/sub/objects/info/alternates subwithsub/sub
	)
'

check_that_two_of_three_alternates_are_used() {
	test_alternate_is_used .shit/objects/info/alternates . &&
	# immediate submodule has alternate:
	test_alternate_is_used .shit/modules/subwithsub/objects/info/alternates subwithsub &&
	# but nested submodule has no alternate:
	test_path_is_missing .shit/modules/subwithsub/modules/sub/objects/info/alternates
}


test_expect_success 'missing nested submodule alternate fails clone and submodule update' '
	test_when_finished "rm -rf supersuper-clone" &&
	test_must_fail shit clone --recursive --reference supersuper2 supersuper2 supersuper-clone &&
	(
		cd supersuper-clone &&
		check_that_two_of_three_alternates_are_used &&
		# update of the submodule fails
		cat >expect <<-\EOF &&
		fatal: submodule '\''sub'\'' cannot add alternate: path ... does not exist
		Failed to clone '\''sub'\''. Retry scheduled
		fatal: submodule '\''sub-dissociate'\'' cannot add alternate: path ... does not exist
		Failed to clone '\''sub-dissociate'\''. Retry scheduled
		fatal: submodule '\''sub'\'' cannot add alternate: path ... does not exist
		Failed to clone '\''sub'\'' a second time, aborting
		fatal: Failed to recurse into submodule path ...
		EOF
		test_must_fail shit submodule update --init --recursive 2>err &&
		grep -e fatal: -e ^Failed err >actual.raw &&
		sed -e "s/path $SQ[^$SQ]*$SQ/path .../" <actual.raw >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'missing nested submodule alternate in --reference-if-able mode' '
	test_when_finished "rm -rf supersuper-clone" &&
	shit clone --recursive --reference-if-able supersuper2 supersuper2 supersuper-clone &&
	(
		cd supersuper-clone &&
		check_that_two_of_three_alternates_are_used &&
		# update of the submodule succeeds
		shit submodule update --init --recursive
	)
'

test_done
