#!/bin/sh

test_description='shit-merge

Do not overwrite changes.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit c0 c0.c &&
	test_commit c1 c1.c &&
	test_commit c1a c1.c "c1 a" &&
	shit reset --hard c0 &&
	test_commit c2 c2.c &&
	shit reset --hard c0 &&
	mkdir sub &&
	echo "sub/f" > sub/f &&
	mkdir sub2 &&
	echo "sub2/f" > sub2/f &&
	shit add sub/f sub2/f &&
	shit commit -m sub &&
	shit tag sub &&
	echo "VERY IMPORTANT CHANGES" > important
'

test_expect_success 'will not overwrite untracked file' '
	shit reset --hard c1 &&
	cp important c2.c &&
	test_must_fail shit merge c2 &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important c2.c
'

test_expect_success 'will overwrite tracked file' '
	shit reset --hard c1 &&
	cp important c2.c &&
	shit add c2.c &&
	shit commit -m important &&
	shit checkout c2
'

test_expect_success 'will not overwrite new file' '
	shit reset --hard c1 &&
	cp important c2.c &&
	shit add c2.c &&
	test_must_fail shit merge c2 &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important c2.c
'

test_expect_success 'will not overwrite staged changes' '
	shit reset --hard c1 &&
	cp important c2.c &&
	shit add c2.c &&
	rm c2.c &&
	test_must_fail shit merge c2 &&
	test_path_is_missing .shit/MERGE_HEAD &&
	shit checkout c2.c &&
	test_cmp important c2.c
'

test_expect_success 'will not overwrite removed file' '
	shit reset --hard c1 &&
	shit rm c1.c &&
	shit commit -m "rm c1.c" &&
	cp important c1.c &&
	test_must_fail shit merge c1a &&
	test_cmp important c1.c &&
	rm c1.c  # Do not leave untracked file in way of future tests
'

test_expect_success 'will not overwrite re-added file' '
	shit reset --hard c1 &&
	shit rm c1.c &&
	shit commit -m "rm c1.c" &&
	cp important c1.c &&
	shit add c1.c &&
	test_must_fail shit merge c1a &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important c1.c
'

test_expect_success 'will not overwrite removed file with staged changes' '
	shit reset --hard c1 &&
	shit rm c1.c &&
	shit commit -m "rm c1.c" &&
	cp important c1.c &&
	shit add c1.c &&
	rm c1.c &&
	test_must_fail shit merge c1a &&
	test_path_is_missing .shit/MERGE_HEAD &&
	shit checkout c1.c &&
	test_cmp important c1.c
'

test_expect_success 'will not overwrite unstaged changes in renamed file' '
	shit reset --hard c1 &&
	shit mv c1.c other.c &&
	shit commit -m rename &&
	cp important other.c &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_must_fail shit merge c1a >out 2>err &&
		test_grep "would be overwritten by merge" err &&
		test_cmp important other.c &&
		test_path_is_missing .shit/MERGE_HEAD
	else
		test_must_fail shit merge c1a >out &&
		test_grep "Refusing to lose dirty file at other.c" out &&
		test_path_is_file other.c~HEAD &&
		test $(shit hash-object other.c~HEAD) = $(shit rev-parse c1a:c1.c) &&
		test_cmp important other.c
	fi
'

test_expect_success 'will not overwrite untracked subtree' '
	shit reset --hard c0 &&
	rm -rf sub &&
	mkdir -p sub/f &&
	cp important sub/f/important &&
	test_must_fail shit merge sub &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important sub/f/important
'

cat >expect <<\EOF
error: The following untracked working tree files would be overwritten by merge:
	sub
	sub2
Please move or remove them before you merge.
Aborting
EOF

test_expect_success 'will not overwrite untracked file in leading path' '
	shit reset --hard c0 &&
	rm -rf sub &&
	cp important sub &&
	cp important sub2 &&
	test_must_fail shit merge sub 2>out &&
	test_cmp out expect &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important sub &&
	test_cmp important sub2 &&
	rm -f sub sub2
'

test_expect_success SYMLINKS 'will not overwrite untracked symlink in leading path' '
	shit reset --hard c0 &&
	rm -rf sub &&
	mkdir sub2 &&
	ln -s sub2 sub &&
	test_must_fail shit merge sub &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'will not be confused by symlink in leading path' '
	shit reset --hard c0 &&
	rm -rf sub &&
	test_ln_s_add sub2 sub &&
	shit commit -m ln &&
	shit checkout sub
'

cat >expect <<\EOF
error: Untracked working tree file 'c0.c' would be overwritten by merge.
fatal: read-tree failed
EOF

test_expect_success 'will not overwrite untracked file on unborn branch' '
	shit reset --hard c0 &&
	shit rm -fr . &&
	shit checkout --orphan new &&
	cp important c0.c &&
	test_must_fail shit merge c0 2>out &&
	test_cmp out expect
'

test_expect_success 'will not overwrite untracked file on unborn branch .shit/MERGE_HEAD sanity etc.' '
	test_when_finished "rm c0.c" &&
	test_path_is_missing .shit/MERGE_HEAD &&
	test_cmp important c0.c
'

test_expect_success 'failed merge leaves unborn branch in the womb' '
	test_must_fail shit rev-parse --verify HEAD
'

test_expect_success 'set up unborn branch and content' '
	shit symbolic-ref HEAD refs/heads/unborn &&
	rm -f .shit/index &&
	echo foo > tracked-file &&
	shit add tracked-file &&
	echo bar > untracked-file
'

test_expect_success 'will not clobber WT/index when merging into unborn' '
	shit merge main &&
	grep foo tracked-file &&
	shit show :tracked-file >expect &&
	grep foo expect &&
	grep bar untracked-file
'

test_done
