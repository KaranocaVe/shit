#!/bin/sh

test_description='grep in sparse checkout

This test creates a repo with the following structure:

.
|-- a
|-- b
|-- dir
|   `-- c
|-- sub
|   |-- A
|   |   `-- a
|   `-- B
|       `-- b
`-- sub2
    `-- a

Where the outer repository has non-cone mode sparsity patterns, sub is a
submodule with cone mode sparsity patterns and sub2 is a submodule that is
excluded by the superproject sparsity patterns. The resulting sparse checkout
should leave the following structure in the working tree:

.
|-- a
|-- sub
|   `-- B
|       `-- b
`-- sub2
    `-- a

But note that sub2 should have the SKIP_WORKTREE bit set.
'

. ./test-lib.sh

test_expect_success 'setup' '
	echo "text" >a &&
	echo "text" >b &&
	mkdir dir &&
	echo "text" >dir/c &&

	shit init sub &&
	(
		cd sub &&
		mkdir A B &&
		echo "text" >A/a &&
		echo "text" >B/b &&
		shit add A B &&
		shit commit -m sub &&
		shit sparse-checkout init --cone &&
		shit sparse-checkout set B
	) &&

	shit init sub2 &&
	(
		cd sub2 &&
		echo "text" >a &&
		shit add a &&
		shit commit -m sub2
	) &&

	shit submodule add ./sub &&
	shit submodule add ./sub2 &&
	shit add a b dir &&
	shit commit -m super &&
	shit sparse-checkout init --no-cone &&
	shit sparse-checkout set "/*" "!b" "!/*/" "sub" &&

	shit tag -am tag-to-commit tag-to-commit HEAD &&
	tree=$(shit rev-parse HEAD^{tree}) &&
	shit tag -am tag-to-tree tag-to-tree $tree &&

	test_path_is_missing b &&
	test_path_is_missing dir &&
	test_path_is_missing sub/A &&
	test_path_is_file a &&
	test_path_is_file sub/B/b &&
	test_path_is_file sub2/a &&
	shit branch -m main
'

# The test below covers a special case: the sparsity patterns exclude '/b' and
# sparse checkout is enabled, but the path exists in the working tree (e.g.
# manually created after `shit sparse-checkout init`).  Although b is marked
# as SKIP_WORKTREE, shit grep should notice it IS present in the worktree and
# report it.
test_expect_success 'working tree grep honors sparse checkout' '
	cat >expect <<-EOF &&
	a:text
	b:new-text
	EOF
	test_when_finished "rm -f b" &&
	echo "new-text" >b &&
	shit grep "text" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep searches unmerged file despite not matching sparsity patterns' '
	cat >expect <<-EOF &&
	b:modified-b-in-branchX
	b:modified-b-in-branchY
	EOF
	test_when_finished "test_might_fail shit merge --abort && \
			    shit checkout main && shit sparse-checkout init" &&

	shit sparse-checkout disable &&
	shit checkout -b branchY main &&
	test_commit modified-b-in-branchY b &&
	shit checkout -b branchX main &&
	test_commit modified-b-in-branchX b &&

	shit sparse-checkout init &&
	test_path_is_missing b &&
	test_must_fail shit merge branchY &&
	shit grep "modified-b" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached searches entries with the SKIP_WORKTREE bit' '
	cat >expect <<-EOF &&
	a:text
	b:text
	dir/c:text
	EOF
	shit grep --cached "text" >actual &&
	test_cmp expect actual
'

# Note that sub2/ is present in the worktree but it is excluded by the sparsity
# patterns.  We also explicitly mark it as SKIP_WORKTREE in case it got cleared
# by previous shit commands.  Thus sub2 starts as SKIP_WORKTREE but since it is
# present in the working tree, grep should recurse into it.
test_expect_success 'grep --recurse-submodules honors sparse checkout in submodule' '
	cat >expect <<-EOF &&
	a:text
	sub/B/b:text
	sub2/a:text
	EOF
	shit update-index --skip-worktree sub2 &&
	shit grep --recurse-submodules "text" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --recurse-submodules --cached searches entries with the SKIP_WORKTREE bit' '
	cat >expect <<-EOF &&
	a:text
	b:text
	dir/c:text
	sub/A/a:text
	sub/B/b:text
	sub2/a:text
	EOF
	shit grep --recurse-submodules --cached "text" >actual &&
	test_cmp expect actual
'

test_expect_success 'working tree grep does not search the index with CE_VALID and SKIP_WORKTREE' '
	cat >expect <<-EOF &&
	a:text
	EOF
	test_when_finished "shit update-index --no-assume-unchanged b" &&
	shit update-index --assume-unchanged b &&
	shit grep text >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached searches index entries with both CE_VALID and SKIP_WORKTREE' '
	cat >expect <<-EOF &&
	a:text
	b:text
	dir/c:text
	EOF
	test_when_finished "shit update-index --no-assume-unchanged b" &&
	shit update-index --assume-unchanged b &&
	shit grep --cached text >actual &&
	test_cmp expect actual
'

test_done
