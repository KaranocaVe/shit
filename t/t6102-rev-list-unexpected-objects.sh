#!/bin/sh

test_description='shit rev-list should handle unexpected object types'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup well-formed objects' '
	blob="$(printf "foo" | shit hash-object -w --stdin)" &&
	tree="$(printf "100644 blob $blob\tfoo" | shit mktree)" &&
	commit="$(shit commit-tree $tree -m "first commit")" &&
	shit cat-file commit $commit >good-commit
'

test_expect_success 'setup unexpected non-blob entry' '
	printf "100644 foo\0$(echo $tree | hex2oct)" >broken-tree &&
	broken_tree="$(shit hash-object -w --literally -t tree broken-tree)"
'

test_expect_success 'TODO (should fail!): traverse unexpected non-blob entry (lone)' '
	sed "s/Z$//" >expect <<-EOF &&
	$broken_tree Z
	$tree foo
	EOF
	shit rev-list --objects $broken_tree >actual &&
	test_cmp expect actual
'

test_expect_success 'traverse unexpected non-blob entry (seen)' '
	test_must_fail shit rev-list --objects $tree $broken_tree >output 2>&1 &&
	test_grep "is not a blob" output
'

test_expect_success 'setup unexpected non-tree entry' '
	printf "40000 foo\0$(echo $blob | hex2oct)" >broken-tree &&
	broken_tree="$(shit hash-object -w --literally -t tree broken-tree)"
'

test_expect_success 'traverse unexpected non-tree entry (lone)' '
	test_must_fail shit rev-list --objects $broken_tree
'

test_expect_success 'traverse unexpected non-tree entry (seen)' '
	test_must_fail shit rev-list --objects $blob $broken_tree >output 2>&1 &&
	test_grep "is not a tree" output
'

test_expect_success 'setup unexpected non-commit parent' '
	sed "/^author/ { h; s/.*/parent $blob/; G; }" <good-commit \
		>broken-commit &&
	broken_commit="$(shit hash-object -w --literally -t commit \
		broken-commit)"
'

test_expect_success 'traverse unexpected non-commit parent (lone)' '
	test_must_fail shit rev-list --objects $broken_commit >output 2>&1 &&
	test_grep "not a commit" output
'

test_expect_success 'traverse unexpected non-commit parent (seen)' '
	test_must_fail shit rev-list --objects $blob $broken_commit \
		>output 2>&1 &&
	test_grep "not a commit" output
'

test_expect_success 'setup unexpected non-tree root' '
	sed -e "s/$tree/$blob/" <good-commit >broken-commit &&
	broken_commit="$(shit hash-object -w --literally -t commit \
		broken-commit)"
'

test_expect_success 'traverse unexpected non-tree root (lone)' '
	test_must_fail shit rev-list --objects $broken_commit
'

test_expect_success 'traverse unexpected non-tree root (seen)' '
	test_must_fail shit rev-list --objects $blob $broken_commit \
		>output 2>&1 &&
	test_grep "not a tree" output
'

test_expect_success 'setup unexpected non-commit tag' '
	shit tag -a -m "tagged commit" tag $commit &&
	shit cat-file tag tag >good-tag &&
	test_when_finished "shit tag -d tag" &&
	sed -e "s/$commit/$blob/" <good-tag >broken-tag &&
	tag=$(shit hash-object -w --literally -t tag broken-tag)
'

test_expect_success 'traverse unexpected non-commit tag (lone)' '
	test_must_fail shit rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-commit tag (seen)' '
	test_must_fail shit rev-list --objects $blob $tag >output 2>&1 &&
	test_grep "not a commit" output
'

test_expect_success 'setup unexpected non-tree tag' '
	shit tag -a -m "tagged tree" tag $tree &&
	shit cat-file tag tag >good-tag &&
	test_when_finished "shit tag -d tag" &&
	sed -e "s/$tree/$blob/" <good-tag >broken-tag &&
	tag=$(shit hash-object -w --literally -t tag broken-tag)
'

test_expect_success 'traverse unexpected non-tree tag (lone)' '
	test_must_fail shit rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-tree tag (seen)' '
	test_must_fail shit rev-list --objects $blob $tag >output 2>&1 &&
	test_grep "not a tree" output
'

test_expect_success 'setup unexpected non-blob tag' '
	shit tag -a -m "tagged blob" tag $blob &&
	shit cat-file tag tag >good-tag &&
	test_when_finished "shit tag -d tag" &&
	sed -e "s/$blob/$commit/" <good-tag >broken-tag &&
	tag=$(shit hash-object -w --literally -t tag broken-tag)
'

test_expect_success 'traverse unexpected non-blob tag (lone)' '
	test_must_fail shit rev-list --objects $tag
'

test_expect_success 'traverse unexpected non-blob tag (seen)' '
	test_must_fail shit rev-list --objects $commit $tag >output 2>&1 &&
	test_grep "not a blob" output
'

test_done
