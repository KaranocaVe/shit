#!/bin/sh

test_description='shit pack-object --include-tag'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

TRASH=$(pwd)

test_expect_success setup '
	echo c >d &&
	shit update-index --add d &&
	tree=$(shit write-tree) &&
	commit=$(shit commit-tree $tree </dev/null) &&
	echo "object $commit" >sig &&
	echo "type commit" >>sig &&
	echo "tag mytag" >>sig &&
	echo "tagger $(shit var shit_COMMITTER_IDENT)" >>sig &&
	echo >>sig &&
	echo "our test tag" >>sig &&
	tag=$(shit mktag <sig) &&
	rm d sig &&
	shit update-ref refs/tags/mytag $tag && {
		echo $tree &&
		echo $commit &&
		shit ls-tree $tree | sed -e "s/.* \\([0-9a-f]*\\)	.*/\\1/"
	} >obj-list
'

test_expect_success 'pack without --include-tag' '
	packname=$(shit pack-objects \
		--window=0 \
		test-no-include <obj-list)
'

test_expect_success 'unpack objects' '
	rm -rf clone.shit &&
	shit init clone.shit &&
	shit -C clone.shit unpack-objects <test-no-include-${packname}.pack
'

test_expect_success 'check unpacked result (have commit, no tag)' '
	shit rev-list --objects $commit >list.expect &&
	test_must_fail shit -C clone.shit cat-file -e $tag &&
	shit -C clone.shit rev-list --objects $commit >list.actual &&
	test_cmp list.expect list.actual
'

test_expect_success 'pack with --include-tag' '
	packname=$(shit pack-objects \
		--window=0 \
		--include-tag \
		test-include <obj-list)
'

test_expect_success 'unpack objects' '
	rm -rf clone.shit &&
	shit init clone.shit &&
	shit -C clone.shit unpack-objects <test-include-${packname}.pack
'

test_expect_success 'check unpacked result (have commit, have tag)' '
	shit rev-list --objects mytag >list.expect &&
	shit -C clone.shit rev-list --objects $tag >list.actual &&
	test_cmp list.expect list.actual
'

# A tag of a tag, where the "inner" tag is not otherwise
# reachable, and a full peel points to a commit reachable from HEAD.
test_expect_success 'create hidden inner tag' '
	test_commit commit &&
	shit tag -m inner inner HEAD &&
	shit tag -m outer outer inner &&
	shit tag -d inner
'

test_expect_success 'pack explicit outer tag' '
	packname=$(
		{
			echo HEAD &&
			echo outer
		} |
		shit pack-objects --revs test-hidden-explicit
	)
'

test_expect_success 'unpack objects' '
	rm -rf clone.shit &&
	shit init clone.shit &&
	shit -C clone.shit unpack-objects <test-hidden-explicit-${packname}.pack
'

test_expect_success 'check unpacked result (have all objects)' '
	shit -C clone.shit rev-list --objects $(shit rev-parse outer HEAD)
'

test_expect_success 'pack implied outer tag' '
	packname=$(
		echo HEAD |
		shit pack-objects --revs --include-tag test-hidden-implied
	)
'

test_expect_success 'unpack objects' '
	rm -rf clone.shit &&
	shit init clone.shit &&
	shit -C clone.shit unpack-objects <test-hidden-implied-${packname}.pack
'

test_expect_success 'check unpacked result (have all objects)' '
	shit -C clone.shit rev-list --objects $(shit rev-parse outer HEAD)
'

test_expect_success 'single-branch clone can transfer tag' '
	rm -rf clone.shit &&
	shit clone --no-local --single-branch -b main . clone.shit &&
	shit -C clone.shit fsck
'

test_done
