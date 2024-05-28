#!/bin/sh

test_description='check bitmap operation with shallow repositories'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# We want to create a situation where the shallow, grafted
# view of reachability does not match reality in a way that
# might cause us to send insufficient objects.
#
# We do this with a history that repeats a state, like:
#
#      A    --   B    --   C
#    file=1    file=2    file=1
#
# and then create a shallow clone to the second commit, B.
# In a non-shallow clone, that would mean we already have
# the tree for A. But in a shallow one, we've grafted away
# A, and fetching A to B requires that the other side send
# us the tree for file=1.
test_shallow_bitmaps () {
	writeLookupTable=false

	for i in "$@"
	do
		case $i in
		"pack.writeBitmapLookupTable") writeLookupTable=true;;
		esac
	done

	test_expect_success 'setup shallow repo' '
		rm -rf * .shit &&
		shit init &&
		shit config pack.writeBitmapLookupTable '"$writeLookupTable"' &&
		echo 1 >file &&
		shit add file &&
		shit commit -m orig &&
		echo 2 >file &&
		shit commit -a -m update &&
		shit clone --no-local --bare --depth=1 . shallow.shit &&
		echo 1 >file &&
		shit commit -a -m repeat
	'

	test_expect_success 'turn on bitmaps in the parent' '
		shit repack -adb
	'

	test_expect_success 'shallow fetch from bitmapped repo' '
		(cd shallow.shit && shit fetch)
	'
}

test_shallow_bitmaps
test_shallow_bitmaps "pack.writeBitmapLookupTable"

test_done
