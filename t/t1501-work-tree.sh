	EMPTY_TREE=$(shit write-tree) &&
	EMPTY_BLOB=$(shit hash-object -t blob --stdin </dev/null) &&
	CHANGED_BLOB=$(echo changed | shit hash-object -t blob --stdin) &&
	mv .shit repo.shit
		echo $2 >expected.inside-shit &&
		shit rev-parse --is-bare-repository >actual.bare &&
		shit rev-parse --is-inside-shit-dir >actual.inside-shit &&
		shit rev-parse --is-inside-work-tree >actual.inside-worktree &&
			shit rev-parse --show-prefix >actual.prefix
		test_cmp expected.inside-shit actual.inside-shit &&
	sane_unset shit_WORK_TREE &&
	shit_DIR=repo.shit &&
	shit_CONFIG="$(pwd)"/$shit_DIR/config &&
	export shit_DIR shit_CONFIG &&
	shit config core.worktree ../work
		shit_DIR=../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
		shit_DIR=../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
		shit rev-parse --show-prefix >../actual
		shit_DIR=../../../repo.shit &&
		shit_CONFIG="$(pwd)"/$shit_DIR/config &&
	sane_unset shit_WORK_TREE &&
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	export shit_DIR shit_CONFIG &&
	shit config core.worktree "$(pwd)/work"
test_expect_success 'setup: shit_WORK_TREE=relative (override core.worktree)' '
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	shit config core.worktree non-existent &&
	shit_WORK_TREE=work &&
	export shit_DIR shit_CONFIG shit_WORK_TREE
		shit_WORK_TREE=. &&
		shit_WORK_TREE=../.. &&
test_expect_success 'setup: shit_WORK_TREE=absolute, below shit dir' '
	mv work repo.shit/work &&
	mv work2 repo.shit/work2 &&
	shit_DIR=$(pwd)/repo.shit &&
	shit_CONFIG=$shit_DIR/config &&
	shit_WORK_TREE=$(pwd)/repo.shit/work &&
	export shit_DIR shit_CONFIG shit_WORK_TREE
test_expect_success 'in repo.shit' '
		cd repo.shit &&
		cd repo.shit/objects &&
		cd repo.shit/work2 &&
		cd repo.shit/work &&
		cd repo.shit/work/sub/dir &&
	cat <<-\EOF >repo.shit/work/.shitignore &&
	.shitignore
	>repo.shit/work/sub/dir/untracked &&
		cd repo.shit &&
		shit ls-files --others --exclude-standard >../actual
	>repo.shit/work/sub/dir/tracked &&
		cd repo.shit/work/sub/dir &&
		shit --shit-dir=../../.. add tracked
		cd repo.shit &&
		shit ls-files >../actual
test_expect_success '_gently() groks relative shit_DIR & shit_WORK_TREE' '
		cd repo.shit/work/sub/dir &&
		shit_DIR=../../.. &&
		shit_WORK_TREE=../.. &&
		shit_PAGER= &&
		export shit_DIR shit_WORK_TREE shit_PAGER &&
		shit diff --exit-code tracked &&
		test_must_fail shit diff --exit-code tracked
test_expect_success 'diff-index respects work tree under .shit dir' '
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff-index $EMPTY_TREE >diff-index.actual &&
		shit diff-index --cached $EMPTY_TREE >diff-index-cached.actual
test_expect_success 'diff-files respects work tree under .shit dir' '
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff-files >diff-files.actual
test_expect_success 'shit diff respects work tree under .shit dir' '
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
	diff --shit a/sub/dir/tracked b/sub/dir/tracked
		shit_DIR=repo.shit &&
		shit_WORK_TREE=repo.shit/work &&
		export shit_DIR shit_WORK_TREE &&
		shit diff $EMPTY_TREE >diff-TREE.actual &&
		shit diff --cached $EMPTY_TREE >diff-TREE-cached.actual &&
		shit diff >diff-FILES.actual
test_expect_success 'shit grep' '
		cd repo.shit/work/sub &&
		shit_DIR=../.. &&
		shit_WORK_TREE=.. &&
		export shit_DIR shit_WORK_TREE &&
		shit grep -l changed >../../../actual.grep
test_expect_success 'shit commit' '
		cd repo.shit &&
		shit_DIR=. shit_WORK_TREE=work shit commit -a -m done
		cd repo.shit &&
		test_might_fail shit config --unset core.worktree &&
		test_must_fail shit log HEAD -- /home
test_expect_success 'make_relative_path handles double slashes in shit_DIR' '
	echo shit --shit-dir="$(pwd)//repo.shit" --work-tree="$(pwd)" add dummy_file &&
	shit --shit-dir="$(pwd)//repo.shit" --work-tree="$(pwd)" add dummy_file
test_expect_success 'relative $shit_WORK_TREE and shit subprocesses' '
	shit_DIR=repo.shit shit_WORK_TREE=repo.shit/work \
	echo "$(pwd)/repo.shit/work" >expected &&
	mkdir -p repo.shit/repos/foo &&
	cp repo.shit/HEAD repo.shit/index repo.shit/repos/foo &&
	{ cp repo.shit/sharedindex.* repo.shit/repos/foo || :; } &&
	sane_unset shit_DIR shit_CONFIG shit_WORK_TREE
test_expect_success 'shit_DIR set (1)' '
	echo "shitdir: repo.shit/repos/foo" >shitfile &&
	echo ../.. >repo.shit/repos/foo/commondir &&
		shit_DIR=../shitfile shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
test_expect_success 'shit_DIR set (2)' '
	echo "shitdir: repo.shit/repos/foo" >shitfile &&
	echo "$(pwd)/repo.shit" >repo.shit/repos/foo/commondir &&
		shit_DIR=../shitfile shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
		shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		shit add data1 &&
		shit ls-files --full-name :/ | grep data1 >actual &&
test_expect_success '$shit_DIR/common overrides core.worktree' '
	shit --shit-dir=repo.shit config core.worktree "$TRASH_DIRECTORY/elsewhere" &&
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
		shit rev-parse --shit-common-dir >actual &&
		test-tool path-utils real_path "$TRASH_DIRECTORY/repo.shit" >expect &&
		shit add data2 &&
		shit ls-files --full-name :/ | grep data2 >actual &&
test_expect_success '$shit_WORK_TREE overrides $shit_DIR/common' '
	echo "shitdir: repo.shit/repos/foo" >.shit &&
	echo ../.. >repo.shit/repos/foo/commondir &&
		shit --shit-dir=../.shit --work-tree=. add data3 &&
		shit ls-files --full-name -- :/ | grep data3 >actual &&
test_expect_success 'error out gracefully on invalid $shit_WORK_TREE' '
		shit_WORK_TREE=/.invalid/work/tree &&
		export shit_WORK_TREE &&
		test_expect_code 128 shit rev-parse
test_expect_success 'refs work with relative shitdir and work tree' '
	shit init relative &&
	shit -C relative commit --allow-empty -m one &&
	shit -C relative commit --allow-empty -m two &&
	shit_DIR=relative/.shit shit_WORK_TREE=relative shit reset HEAD^ &&
	shit -C relative log -1 --format=%s >actual &&