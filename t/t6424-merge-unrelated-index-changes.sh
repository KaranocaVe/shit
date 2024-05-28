#!/bin/sh

test_description="merges with unrelated index changes"

. ./test-lib.sh

# Testcase for some simple merges
#   A
#   o-------o B
#    \
#     \-----o C
#      \
#       \---o D
#        \
#         \-o E
#          \
#           o F
#   Commit A: some file a
#   Commit B: adds file b, modifies end of a
#   Commit C: adds file c
#   Commit D: adds file d, modifies beginning of a
#   Commit E: renames a->subdir/a, adds subdir/e
#   Commit F: empty commit

test_expect_success 'setup trivial merges' '
	test_seq 1 10 >a &&
	shit add a &&
	test_tick && shit commit -m A &&

	shit branch A &&
	shit branch B &&
	shit branch C &&
	shit branch D &&
	shit branch E &&
	shit branch F &&

	shit checkout B &&
	echo b >b &&
	echo 11 >>a &&
	shit add a b &&
	test_tick && shit commit -m B &&

	shit checkout C &&
	echo c >c &&
	shit add c &&
	test_tick && shit commit -m C &&

	shit checkout D &&
	test_seq 2 10 >a &&
	echo d >d &&
	shit add a d &&
	test_tick && shit commit -m D &&

	shit checkout E &&
	mkdir subdir &&
	shit mv a subdir/a &&
	echo e >subdir/e &&
	shit add subdir &&
	test_tick && shit commit -m E &&

	shit checkout F &&
	test_tick && shit commit --allow-empty -m F
'

test_expect_success 'ff update' '
	shit reset --hard &&
	shit checkout A^0 &&

	touch random_file && shit add random_file &&

	shit merge E^0 &&

	test_must_fail shit rev-parse HEAD:random_file &&
	test "$(shit diff --name-only --cached E)" = "random_file" &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file
'

test_expect_success 'ff update, important file modified' '
	shit reset --hard &&
	shit checkout A^0 &&

	mkdir subdir &&
	touch subdir/e &&
	shit add subdir/e &&

	test_must_fail shit merge E^0 &&
	test_path_is_file subdir/e &&
	shit rev-parse --verify :subdir/e &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'resolve, trivial' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s resolve C^0 &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'resolve, non-trivial' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s resolve D^0 &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'resolve, trivial, related file removed' '
	shit reset --hard &&
	shit checkout B^0 &&

	shit rm a &&
	test_path_is_missing a &&

	test_must_fail shit merge -s resolve C^0 &&

	test_path_is_missing a &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'resolve, non-trivial, related file removed' '
	shit reset --hard &&
	shit checkout B^0 &&

	shit rm a &&
	test_path_is_missing a &&

	# We also ask for recursive in order to turn off the "allow_trivial"
	# setting in builtin/merge.c, and ensure that resolve really does
	# correctly fail the merge (I guess this also tests that recursive
	# correctly fails the merge, but the main thing we are attempting
	# to test here is resolve and are just using the side effect of
	# adding recursive to ensure that resolve is actually tested rather
	# than the trivial merge codepath)
	test_must_fail shit merge -s resolve -s recursive D^0 &&

	test_path_is_missing a &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'recursive' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s recursive C^0 &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'recursive, when merge branch matches merge base' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s recursive F^0 &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'merge-recursive, when index==head but head!=HEAD' '
	shit reset --hard &&
	shit checkout C^0 &&

	# Make index match B
	shit diff C B -- | shit apply --cached &&
	test_when_finished "shit clean -fd" &&  # Do not leave untracked around
	# Merge B & F, with B as "head"
	shit merge-recursive A -- B F > out &&
	test_grep "Already up to date" out
'

test_expect_success 'recursive, when file has staged changes not matching HEAD nor what a merge would give' '
	shit reset --hard &&
	shit checkout B^0 &&

	mkdir subdir &&
	test_seq 1 10 >subdir/a &&
	shit add subdir/a &&
	shit rev-parse --verify :subdir/a >expect &&

	# We have staged changes; merge should error out
	test_must_fail shit merge -s recursive E^0 2>err &&
	shit rev-parse --verify :subdir/a >actual &&
	test_cmp expect actual &&
	test_grep "changes to the following files would be overwritten" err
'

test_expect_success 'recursive, when file has staged changes matching what a merge would give' '
	shit reset --hard &&
	shit checkout B^0 &&

	mkdir subdir &&
	test_seq 1 11 >subdir/a &&
	shit add subdir/a &&
	shit rev-parse --verify :subdir/a >expect &&

	# We have staged changes; merge should error out
	test_must_fail shit merge -s recursive E^0 2>err &&
	shit rev-parse --verify :subdir/a >actual &&
	test_cmp expect actual &&
	test_grep "changes to the following files would be overwritten" err
'

test_expect_success 'octopus, unrelated file touched' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge C^0 D^0 &&
	test_path_is_missing .shit/MERGE_HEAD &&
	shit rev-parse --verify :random_file &&
	test_path_exists random_file
'

test_expect_success 'octopus, related file removed' '
	shit reset --hard &&
	shit checkout B^0 &&

	shit rm b &&

	test_must_fail shit merge C^0 D^0 &&
	test_path_is_missing b &&
	test_must_fail shit rev-parse --verify :b &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'octopus, related file modified' '
	shit reset --hard &&
	shit checkout B^0 &&

	echo 12 >>a && shit add a &&
	shit rev-parse --verify :a >expect &&

	test_must_fail shit merge C^0 D^0 &&
	test_path_is_file a &&
	shit rev-parse --verify :a >actual &&
	test_cmp expect actual &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'ours' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s ours C^0 &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'subtree' '
	shit reset --hard &&
	shit checkout B^0 &&

	touch random_file && shit add random_file &&

	test_must_fail shit merge -s subtree E^0 &&
	test_path_is_file random_file &&
	shit rev-parse --verify :random_file &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success 'avoid failure due to stat-dirty files' '
	shit reset --hard &&
	shit checkout B^0 &&

	# Make "a" be stat-dirty
	test-tool chmtime =+1 a &&

	# stat-dirty file should not prevent stash creation in builtin/merge.c
	shit merge -s resolve -s recursive D^0
'

test_expect_success 'with multiple strategies, recursive or ort failure do not early abort' '
	shit reset --hard &&
	shit checkout B^0 &&

	test_seq 0 10 >a &&
	shit add a &&
	shit rev-parse :a >expect &&

	sane_unset shit_TEST_MERGE_ALGORITHM &&
	test_must_fail shit merge -s recursive -s ort -s octopus C^0 >output 2>&1 &&

	grep "Trying merge strategy recursive..." output &&
	grep "Trying merge strategy ort..." output &&
	grep "Trying merge strategy octopus..." output &&
	grep "No merge strategy handled the merge." output &&

	# Changes to "a" should remain staged
	shit rev-parse :a >actual &&
	test_cmp expect actual
'

test_done
