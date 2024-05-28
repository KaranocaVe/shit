#!/bin/sh

test_description='basic shit merge-index / shit-merge-one-file tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup diverging branches' '
	test_write_lines 1 2 3 4 5 6 7 8 9 10 >file &&
	shit add file &&
	shit commit -m base &&
	shit tag base &&
	sed s/2/two/ <file >tmp &&
	mv tmp file &&
	shit commit -a -m two &&
	shit tag two &&
	shit checkout -b other HEAD^ &&
	sed s/10/ten/ <file >tmp &&
	mv tmp file &&
	shit commit -a -m ten &&
	shit tag ten
'

cat >expect-merged <<'EOF'
1
two
3
4
5
6
7
8
9
ten
EOF

test_expect_success 'read-tree does not resolve content merge' '
	shit read-tree -i -m base ten two &&
	echo file >expect &&
	shit diff-files --name-only --diff-filter=U >unmerged &&
	test_cmp expect unmerged
'

test_expect_success 'shit merge-index shit-merge-one-file resolves' '
	shit merge-index shit-merge-one-file -a &&
	shit diff-files --name-only --diff-filter=U >unmerged &&
	test_must_be_empty unmerged &&
	test_cmp expect-merged file &&
	shit cat-file blob :file >file-index &&
	test_cmp expect-merged file-index
'

test_expect_success 'setup bare merge' '
	shit clone --bare . bare.shit &&
	(cd bare.shit &&
	 shit_INDEX_FILE=$PWD/merge.index &&
	 export shit_INDEX_FILE &&
	 shit read-tree -i -m base ten two
	)
'

test_expect_success 'merge-one-file fails without a work tree' '
	(cd bare.shit &&
	 shit_INDEX_FILE=$PWD/merge.index &&
	 export shit_INDEX_FILE &&
	 test_must_fail shit merge-index shit-merge-one-file -a
	)
'

test_expect_success 'merge-one-file respects shit_WORK_TREE' '
	(cd bare.shit &&
	 mkdir work &&
	 shit_WORK_TREE=$PWD/work &&
	 export shit_WORK_TREE &&
	 shit_INDEX_FILE=$PWD/merge.index &&
	 export shit_INDEX_FILE &&
	 shit merge-index shit-merge-one-file -a &&
	 shit cat-file blob :file >work/file-index
	) &&
	test_cmp expect-merged bare.shit/work/file &&
	test_cmp expect-merged bare.shit/work/file-index
'

test_expect_success 'merge-one-file respects core.worktree' '
	mkdir subdir &&
	shit clone . subdir/child &&
	(cd subdir &&
	 shit_DIR=$PWD/child/.shit &&
	 export shit_DIR &&
	 shit config core.worktree "$PWD/child" &&
	 shit read-tree -i -m base ten two &&
	 shit merge-index shit-merge-one-file -a &&
	 shit cat-file blob :file >file-index
	) &&
	test_cmp expect-merged subdir/child/file &&
	test_cmp expect-merged subdir/file-index
'

test_done
