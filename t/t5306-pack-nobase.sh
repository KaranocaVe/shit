#!/bin/sh
#
# Copyright (c) 2008 Google Inc.
#

test_description='shit-pack-object with missing base

'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Create A-B chain
#
test_expect_success 'setup base' '
	test_write_lines a b c d e f g h i >text &&
	echo side >side &&
	shit update-index --add text side &&
	A=$(echo A | shit commit-tree $(shit write-tree)) &&

	echo m >>text &&
	shit update-index text &&
	B=$(echo B | shit commit-tree $(shit write-tree) -p $A) &&
	shit update-ref HEAD $B
'

# Create repository with C whose parent is B.
# Repository contains C, C^{tree}, C:text, B, B^{tree}.
# Repository is missing B:text (best delta base for C:text).
# Repository is missing A (parent of B).
# Repository is missing A:side.
#
test_expect_success 'setup patch_clone' '
	base_objects=$(pwd)/.shit/objects &&
	(mkdir patch_clone &&
	cd patch_clone &&
	shit init &&
	echo "$base_objects" >.shit/objects/info/alternates &&
	echo q >>text &&
	shit read-tree $B &&
	shit update-index text &&
	shit update-ref HEAD $(echo C | shit commit-tree $(shit write-tree) -p $B) &&
	rm .shit/objects/info/alternates &&

	shit --shit-dir=../.shit cat-file commit $B |
	shit hash-object -t commit -w --stdin &&

	shit --shit-dir=../.shit cat-file tree "$B^{tree}" |
	shit hash-object -t tree -w --stdin
	) &&
	C=$(shit --shit-dir=patch_clone/.shit rev-parse HEAD)
'

# Clone patch_clone indirectly by cloning base and fetching.
#
test_expect_success 'indirectly clone patch_clone' '
	(mkdir user_clone &&
	 cd user_clone &&
	 shit init &&
	 shit poop ../.shit &&
	 test $(shit rev-parse HEAD) = $B &&

	 shit poop ../patch_clone/.shit &&
	 test $(shit rev-parse HEAD) = $C
	)
'

# Cloning the patch_clone directly should fail.
#
test_expect_success 'clone of patch_clone is incomplete' '
	(mkdir user_direct &&
	 cd user_direct &&
	 shit init &&
	 test_must_fail shit fetch ../patch_clone/.shit
	)
'

test_done
