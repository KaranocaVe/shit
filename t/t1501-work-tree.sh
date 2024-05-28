#!/bin/sh

test_description='test separate work tree'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	EMPTY_TREE=$(shit write-tree) &&
	EMPTY_BLOB=$(shit hash-object -t blob --stdin </dev/null) &&
	CHANGED_BLOB=$(echo changed | shit hash-object -t blob --stdin) &&
	EMPTY_BLOB7=$(echo $EMPTY_BLOB | sed "s/\(.......\).*/\1/") &&
	CHANGED_BLOB7=$(echo $CHANGED_BLOB | sed "s/\(.......\).*/\1/") &&

	mkdir -p work/sub/dir &&
	mkdir -p work2 &&
	mv .shit repo.shit
'

test_expect_success 'setup: helper for testing rev-parse' '
	test_rev_parse() {
		echo $1 >expected.bare &&
		echo $2 >expected.inside-shit &&
		echo $3 >expected.inside-worktree &&
		if test $# -ge 4
		then
			echo $4 >expected.prefix
		fi &&

		shit rev-parse --is-bare-repository >actual.bare &&
		shit rev-parse --is-inside-shit-dir >actual.inside-shit &&
		shit rev-parse --is-inside-work-tree >actual.inside-worktree &&
		if test $# -ge 4
		then
			shit rev-parse --show-prefix >actual.prefix
		fi &&

		test_cmp expected.bare actual.bare &&
		test_cmp expected.inside-shit actual.inside-shit &&
		test_cmp expected.inside-worktree actual.inside-worktree &&
		if test $# -ge 4
		then
			# rev-parse --show-prefix should output
			# a single newline when at the top of the work tree,
			# but we test for that separately.
			test -z "$4" && test_must_be_empty actual.prefix ||
			test_cmp expected.prefix actual.prefix
		fi
	}
'

test_expect_success 'setup: core.worktree = relative path' '
	sane_unset shit_WORK_TREE &&
	shit_DIR=repo.shit &&
	shit_CONFIG="$(pwd)"/$shit_DIR/config &&
	export shit_DIR shit_CONFIG &&
	shit config core.worktree ../work
'

test_expect_success 'outside' '
	test_rev_parse false false false
'

test_expect_success 'inside work tree' '
	(
		cd work &&
		shit_DIR=../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
		test_rev_parse false false true ""
	)
'

test_expect_success 'empty prefix is actually written out' '
	echo >expected &&
	(
		cd work &&
		shit_DIR=../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
		shit rev-parse --show-prefix >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'subdir of work tree' '
	(
		cd work/sub/dir &&
		shit_DIR=../../../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
		test_rev_parse false false true sub/dir/
	)
'

test_expect_success 'setup: core.worktree = absolute path' '
	sane_unset shit_WORK_TREE &&
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	export shit_DIR shit_CONFIG &&
	shit config core.worktree "$(pwd)/work"
'

test_expect_success 'outside' '
	test_rev_parse false false false &&
	(
		cd work2 &&
		test_rev_parse false false false
	)
'

test_expect_success 'inside work tree' '
	(
		cd work &&
		test_rev_parse false false true ""
	)
'

test_expect_success 'subdir of work tree' '
	(
		cd work/sub/dir &&
		test_rev_parse false false true sub/dir/
	)
'

test_expect_success 'setup: shit_WORK_TREE=relative (override core.worktree)' '
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	shit config core.worktree non-existent &&
	shit_WORK_TREE=work &&
	export shit_DIR shit_CONFIG shit_WORK_TREE
'

test_expect_success 'outside' '
	test_rev_parse false false false &&
	(
		cd work2 &&
		test_rev_parse false false false
	)
'

test_expect_success 'inside work tree' '
	(
		cd work &&
		shit_WORK_TREE=. &&
		test_rev_parse false false true ""
	)
'

test_expect_success 'subdir of work tree' '
	(
		cd work/sub/dir &&
		shit_WORK_TREE=../.. &&
		test_rev_parse false false true sub/dir/
	)
'

test_expect_success 'setup: shit_WORK_TREE=absolute, below shit dir' '
	mv work repo.shit/work &&
	mv work2 repo.shit/work2 &&
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	shit_WORK_TREE=$(pwd)/repo.shit/work &&
	export shit_DIR shit_CONFIG shit_WORK_TREE
'

test_expect_success 'outside' '
	echo outside &&
	test_rev_parse false false false
'

test_expect_success 'in repo.shit' '
	(
		cd repo.shit &&
		test_rev_parse false true false
	) &&
	(
		cd repo.shit/objects &&
		test_rev_parse false true false
	) &&
	(
		cd repo.shit/work2 &&
		test_rev_parse false true false
	)
'

test_expect_success 'inside work tree' '
	(
		cd repo.shit/work &&
		test_rev_parse false true true ""
	)
'

test_expect_success 'subdir of work tree' '
	(
		cd repo.shit/work/sub/dir &&
		test_rev_parse false true true sub/dir/
	)
'

test_expect_success 'find work tree from repo' '
	echo sub/dir/untracked >expected &&
	cat <<-\EOF >repo.shit/work/.shitignore &&
	expected.*
	actual.*
	.shitignore
	EOF
	>repo.shit/work/sub/dir/untracked &&
	(
		cd repo.shit &&
		shit ls-files --others --exclude-standard >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'find work tree from work tree' '
	echo sub/dir/tracked >expected &&
	>repo.shit/work/sub/dir/tracked &&
	(
		cd repo.shit/work/sub/dir &&
		shit --shit-dir=../../.. add tracked
	) &&
	(
		cd repo.shit &&
		shit ls-files >../actual
	) &&
	test_cmp expected actual
'

test_expect_success '_gently() groks relative shit_DIR & shit_WORK_TREE' '
	(
		cd repo.shit/work/sub/dir &&
		shit_DIR=../../.. &&
		shit_WORK_TREE=../.. &&
		shit_PAGER= &&
		export shit_DIR shit_WORK_TREE shit_PAGER &&

		shit diff --exit-code tracked &&
		echo changed >tracked &&
		test_must_fail shit diff --exit-code tracked
	)
'

test_expect_success 'diff-index respects work tree under .shit dir' '
	cat >diff-index-cached.expected <<-EOF &&
	:000000 100644 $ZERO_OID $EMPTY_BLOB A	sub/dir/tracked
	EOF
	cat >diff-index.expected <<-EOF &&
	:000000 100644 $ZERO_OID $ZERO_OID A	sub/dir/tracked
	EOF

	(
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff-index $EMPTY_TREE >diff-index.actual &&
		shit diff-index --cached $EMPTY_TREE >diff-index-cached.actual
	) &&
	test_cmp diff-index.expected diff-index.actual &&
	test_cmp diff-index-cached.expected diff-index-cached.actual
'

test_expect_success 'diff-files respects work tree under .shit dir' '
	cat >diff-files.expected <<-EOF &&
	:100644 100644 $EMPTY_BLOB $ZERO_OID M	sub/dir/tracked
	EOF

	(
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff-files >diff-files.actual
	) &&
	test_cmp diff-files.expected diff-files.actual
'

test_expect_success 'shit diff respects work tree under .shit dir' '
	cat >diff-TREE.expected <<-EOF &&
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
	new file mode 100644
	index 0000000..$CHANGED_BLOB7
	--- /dev/null
	+++ b/sub/dir/tracked
	@@ -0,0 +1 @@
	+changed
	EOF
	cat >diff-TREE-cached.expected <<-EOF &&
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
	new file mode 100644
	index 0000000..$EMPTY_BLOB7
	EOF
	cat >diff-FILES.expected <<-EOF &&
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
	index $EMPTY_BLOB7..$CHANGED_BLOB7 100644
	--- a/sub/dir/tracked
	+++ b/sub/dir/tracked
	@@ -0,0 +1 @@
	+changed
	EOF

	(
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff $EMPTY_TREE >diff-TREE.actual &&
		shit diff --cached $EMPTY_TREE >diff-TREE-cached.actual &&
		shit diff >diff-FILES.actual
	) &&
	test_cmp diff-TREE.expected diff-TREE.actual &&
	test_cmp diff-TREE-cached.expected diff-TREE-cached.actual &&
	test_cmp diff-FILES.expected diff-FILES.actual
'

test_expect_success 'shit grep' '
	echo dir/tracked >expected.grep &&
	(
		cd repo.shit/work/sub &&
		shit_DIR=../.. &&
		shit_WORK_TREE=.. &&
		export shit_DIR shit_WORK_TREE &&
		shit grep -l changed >../../../actual.grep
	) &&
	test_cmp expected.grep actual.grep
'

test_expect_success 'shit commit' '
	(
		cd repo.shit &&
		shit_DIR=. shit_WORK_TREE=work shit commit -a -m done
	)
'

test_expect_success 'absolute pathspec should fail gracefully' '
	(
		cd repo.shit &&
		test_might_fail shit config --unset core.worktree &&
		test_must_fail shit log HEAD -- /home
	)
'

test_expect_success 'make_relative_path handles double slashes in shit_DIR' '
	>dummy_file &&
	echo shit --shit-dir="$(pwd)//repo.shit" --work-tree="$(pwd)" add dummy_file &&
	shit --shit-dir="$(pwd)//repo.shit" --work-tree="$(pwd)" add dummy_file
'

test_expect_success 'relative $shit_WORK_TREE and shit subprocesses' '
	shit_DIR=repo.shit shit_WORK_TREE=repo.shit/work \
	test-tool subprocess --setup-work-tree rev-parse --show-toplevel >actual &&
	echo "$(pwd)/repo.shit/work" >expected &&
	test_cmp expected actual
'

test_expect_success 'Multi-worktree setup' '
	mkdir work &&
	mkdir -p repo.shit/repos/foo &&
	cp repo.shit/HEAD repo.shit/index repo.shit/repos/foo &&
	{ cp repo.shit/sharedindex.* repo.shit/repos/foo || :; } &&
	sane_unset shit_DIR shit_CONFIG shit_WORK_TREE
'

test_expect_success 'shit_DIR set (1)' '
	echo "shitdir: repo.shit/repos/foo" >shitfile &&
	echo ../.. >repo.shit/repos/foo/commondir &&
	(
		cd work &&
		shit_DIR=../shitfile shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'shit_DIR set (2)' '
	echo "shitdir: repo.shit/repos/foo" >shitfile &&
	echo "$(pwd)/repo.shit" >repo.shit/repos/foo/commondir &&
	(
		cd work &&
		shit_DIR=../shitfile shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'Auto discovery' '
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
	(
		cd work &&
		shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		test_cmp expect actual &&
		echo haha >data1 &&
		shit add data1 &&
		shit ls-files --full-name :/ | grep data1 >actual &&
		echo work/data1 >expect &&
		test_cmp expect actual
	)
'

test_expect_success '$shit_DIR/common overrides core.worktree' '
	mkdir elsewhere &&
	shit --shit-dir=repo.shit config core.worktree "$TRASH_DIRECTORY/elsewhere" &&
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
	(
		cd work &&
		shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		test_cmp expect actual &&
		echo haha >data2 &&
		shit add data2 &&
		shit ls-files --full-name :/ | grep data2 >actual &&
		echo work/data2 >expect &&
		test_cmp expect actual
	)
'

test_expect_success '$shit_WORK_TREE overrides $shit_DIR/common' '
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
	(
		cd work &&
		echo haha >data3 &&
		shit --shit-dir=../.shit --work-tree=. add data3 &&
		shit ls-files --full-name -- :/ | grep data3 >actual &&
		echo data3 >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'error out gracefully on invalid $shit_WORK_TREE' '
	(
		shit_WORK_TREE=/.invalid/work/tree &&
		export shit_WORK_TREE &&
		test_expect_code 128 shit rev-parse
	)
'

test_expect_success 'refs work with relative shitdir and work tree' '
	shit init relative &&
	shit -C relative commit --allow-empty -m one &&
	shit -C relative commit --allow-empty -m two &&

	shit_DIR=relative/.shit shit_WORK_TREE=relative shit reset HEAD^ &&

	shit -C relative log -1 --format=%s >actual &&
	echo one >expect &&
	test_cmp expect actual
'

test_done
