#!/bin/sh

test_description="recursive merge corner cases w/ renames but not criss-crosses"
# t6036 has corner cases that involve both criss-cross merges and renames

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-merge.sh

test_setup_rename_delete_untracked () {
	shit init rename-delete-untracked &&
	(
		cd rename-delete-untracked &&

		echo "A pretty inscription" >ring &&
		shit add ring &&
		test_tick &&
		shit commit -m beginning &&

		shit branch people &&
		shit checkout -b rename-the-ring &&
		shit mv ring one-ring-to-rule-them-all &&
		test_tick &&
		shit commit -m fullname &&

		shit checkout people &&
		shit rm ring &&
		echo gollum >owner &&
		shit add owner &&
		test_tick &&
		shit commit -m track-people-instead-of-objects &&
		echo "Myyy PRECIOUSSS" >ring
	)
}

test_expect_success "Does shit preserve Gollum's precious artifact?" '
	test_setup_rename_delete_untracked &&
	(
		cd rename-delete-untracked &&

		test_must_fail shit merge -s recursive rename-the-ring &&

		# Make sure shit did not delete an untracked file
		test_path_is_file ring
	)
'

# Testcase setup for rename/modify/add-source:
#   Commit A: new file: a
#   Commit B: modify a slightly
#   Commit C: rename a->b, add completely different a
#
# We should be able to merge B & C cleanly

test_setup_rename_modify_add_source () {
	shit init rename-modify-add-source &&
	(
		cd rename-modify-add-source &&

		printf "1\n2\n3\n4\n5\n6\n7\n" >a &&
		shit add a &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		echo 8 >>a &&
		shit add a &&
		shit commit -m B &&

		shit checkout -b C A &&
		shit mv a b &&
		echo something completely different >a &&
		shit add a &&
		shit commit -m C
	)
}

test_expect_failure 'rename/modify/add-source conflict resolvable' '
	test_setup_rename_modify_add_source &&
	(
		cd rename-modify-add-source &&

		shit checkout B^0 &&

		shit merge -s recursive C^0 &&

		shit rev-parse >expect \
			B:a   C:a     &&
		shit rev-parse >actual \
			b     c       &&
		test_cmp expect actual
	)
'

test_setup_break_detection_1 () {
	shit init break-detection-1 &&
	(
		cd break-detection-1 &&

		printf "1\n2\n3\n4\n5\n" >a &&
		echo foo >b &&
		shit add a b &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a c &&
		echo "Completely different content" >a &&
		shit add a &&
		shit commit -m B &&

		shit checkout -b C A &&
		echo 6 >>a &&
		shit add a &&
		shit commit -m C
	)
}

test_expect_failure 'conflict caused if rename not detected' '
	test_setup_break_detection_1 &&
	(
		cd break-detection-1 &&

		shit checkout -q C^0 &&
		shit merge -s recursive B^0 &&

		shit ls-files -s >out &&
		test_line_count = 3 out &&
		shit ls-files -u >out &&
		test_line_count = 0 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_line_count = 6 c &&
		shit rev-parse >expect \
			B:a   A:b     &&
		shit rev-parse >actual \
			:0:a  :0:b    &&
		test_cmp expect actual
	)
'

test_setup_break_detection_2 () {
	shit init break-detection-2 &&
	(
		cd break-detection-2 &&

		printf "1\n2\n3\n4\n5\n" >a &&
		echo foo >b &&
		shit add a b &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b D A &&
		echo 7 >>a &&
		shit add a &&
		shit mv a c &&
		echo "Completely different content" >a &&
		shit add a &&
		shit commit -m D &&

		shit checkout -b E A &&
		shit rm a &&
		echo "Completely different content" >>a &&
		shit add a &&
		shit commit -m E
	)
}

test_expect_failure 'missed conflict if rename not detected' '
	test_setup_break_detection_2 &&
	(
		cd break-detection-2 &&

		shit checkout -q E^0 &&
		test_must_fail shit merge -s recursive D^0
	)
'

# Tests for undetected rename/add-source causing a file to erroneously be
# deleted (and for mishandled rename/rename(1to1) causing the same issue).
#
# This test uses a rename/rename(1to1)+add-source conflict (1to1 means the
# same file is renamed on both sides to the same thing; it should trigger
# the 1to2 logic, which it would do if the add-source didn't cause issues
# for shit's rename detection):
#   Commit A: new file: a
#   Commit B: rename a->b
#   Commit C: rename a->b, add unrelated a

test_setup_break_detection_3 () {
	shit init break-detection-3 &&
	(
		cd break-detection-3 &&

		printf "1\n2\n3\n4\n5\n" >a &&
		shit add a &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a b &&
		shit commit -m B &&

		shit checkout -b C A &&
		shit mv a b &&
		echo foobar >a &&
		shit add a &&
		shit commit -m C
	)
}

test_expect_failure 'detect rename/add-source and preserve all data' '
	test_setup_break_detection_3 &&
	(
		cd break-detection-3 &&

		shit checkout B^0 &&

		shit merge -s recursive C^0 &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_file a &&
		test_path_is_file b &&

		shit rev-parse >expect \
			A:a   C:a     &&
		shit rev-parse >actual \
			:0:b  :0:a    &&
		test_cmp expect actual
	)
'

test_expect_failure 'detect rename/add-source and preserve all data, merge other way' '
	test_setup_break_detection_3 &&
	(
		cd break-detection-3 &&

		shit checkout C^0 &&

		shit merge -s recursive B^0 &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_file a &&
		test_path_is_file b &&

		shit rev-parse >expect \
			A:a   C:a     &&
		shit rev-parse >actual \
			:0:b  :0:a    &&
		test_cmp expect actual
	)
'

test_setup_rename_directory () {
	shit init rename-directory-$1 &&
	(
		cd rename-directory-$1 &&

		printf "1\n2\n3\n4\n5\n6\n" >file &&
		shit add file &&
		test_tick &&
		shit commit -m base &&
		shit tag base &&

		shit checkout -b right &&
		echo 7 >>file &&
		mkdir newfile &&
		echo junk >newfile/realfile &&
		shit add file newfile/realfile &&
		test_tick &&
		shit commit -m right &&

		shit checkout -b left-conflict base &&
		echo 8 >>file &&
		shit add file &&
		shit mv file newfile &&
		test_tick &&
		shit commit -m left &&

		shit checkout -b left-clean base &&
		echo 0 >newfile &&
		cat file >>newfile &&
		shit add newfile &&
		shit rm file &&
		test_tick &&
		shit commit -m left
	)
}

test_expect_success 'rename/directory conflict + clean content merge' '
	test_setup_rename_directory 1a &&
	(
		cd rename-directory-1a &&

		shit checkout left-clean^0 &&

		test_must_fail shit merge -s recursive right^0 &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 1 out &&
		shit ls-files -o >out &&
		if test "$shit_TEST_MERGE_ALGORITHM" = ort
		then
			test_line_count = 1 out
		else
			test_line_count = 2 out
		fi &&

		echo 0 >expect &&
		shit cat-file -p base:file >>expect &&
		echo 7 >>expect &&
		test_cmp expect newfile~HEAD &&

		test_path_is_file newfile/realfile &&
		test_path_is_file newfile~HEAD
	)
'

test_expect_success 'rename/directory conflict + content merge conflict' '
	test_setup_rename_directory 1b &&
	(
		cd rename-directory-1b &&

		shit reset --hard &&
		shit clean -fdqx &&

		shit checkout left-conflict^0 &&

		test_must_fail shit merge -s recursive right^0 &&

		shit ls-files -s >out &&
		test_line_count = 4 out &&
		shit ls-files -u >out &&
		test_line_count = 3 out &&
		shit ls-files -o >out &&
		if test "$shit_TEST_MERGE_ALGORITHM" = ort
		then
			test_line_count = 1 out
		else
			test_line_count = 2 out
		fi &&

		shit cat-file -p left-conflict:newfile >left &&
		shit cat-file -p base:file    >base &&
		shit cat-file -p right:file   >right &&
		test_must_fail shit merge-file \
			-L "HEAD:newfile" \
			-L "" \
			-L "right^0:file" \
			left base right &&
		test_cmp left newfile~HEAD &&

		shit rev-parse >expect   \
			base:file       left-conflict:newfile right:file &&
		if test "$shit_TEST_MERGE_ALGORITHM" = ort
		then
			shit rev-parse >actual \
				:1:newfile~HEAD :2:newfile~HEAD :3:newfile~HEAD
		else
			shit rev-parse >actual \
				:1:newfile      :2:newfile      :3:newfile
		fi &&
		test_cmp expect actual &&

		test_path_is_file newfile/realfile &&
		test_path_is_file newfile~HEAD
	)
'

test_setup_rename_directory_2 () {
	shit init rename-directory-2 &&
	(
		cd rename-directory-2 &&

		mkdir sub &&
		printf "1\n2\n3\n4\n5\n6\n" >sub/file &&
		shit add sub/file &&
		test_tick &&
		shit commit -m base &&
		shit tag base &&

		shit checkout -b right &&
		echo 7 >>sub/file &&
		shit add sub/file &&
		test_tick &&
		shit commit -m right &&

		shit checkout -b left base &&
		echo 0 >newfile &&
		cat sub/file >>newfile &&
		shit rm sub/file &&
		mv newfile sub &&
		shit add sub &&
		test_tick &&
		shit commit -m left
	)
}

test_expect_success 'disappearing dir in rename/directory conflict handled' '
	test_setup_rename_directory_2 &&
	(
		cd rename-directory-2 &&

		shit checkout left^0 &&

		shit merge -s recursive right^0 &&

		shit ls-files -s >out &&
		test_line_count = 1 out &&
		shit ls-files -u >out &&
		test_line_count = 0 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		echo 0 >expect &&
		shit cat-file -p base:sub/file >>expect &&
		echo 7 >>expect &&
		test_cmp expect sub &&

		test_path_is_file sub
	)
'

# Test for basic rename/add-dest conflict, with rename needing content merge:
#   Commit O: a
#   Commit A: rename a->b, modifying b too
#   Commit B: modify a, add different b

test_setup_rename_with_content_merge_and_add () {
	shit init rename-with-content-merge-and-add-$1 &&
	(
		cd rename-with-content-merge-and-add-$1 &&

		test_seq 1 5 >a &&
		shit add a &&
		shit commit -m O &&
		shit tag O &&

		shit checkout -b A O &&
		shit mv a b &&
		test_seq 0 5 >b &&
		shit add b &&
		shit commit -m A &&

		shit checkout -b B O &&
		echo 6 >>a &&
		echo hello world >b &&
		shit add a b &&
		shit commit -m B
	)
}

test_expect_success 'handle rename-with-content-merge vs. add' '
	test_setup_rename_with_content_merge_and_add AB &&
	(
		cd rename-with-content-merge-and-add-AB &&

		shit checkout A^0 &&

		test_must_fail shit merge -s recursive B^0 >out &&
		test_grep "CONFLICT (.*/add)" out &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		# Also, make sure both unmerged entries are for "b"
		shit ls-files -u b >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_missing a &&
		test_path_is_file b &&

		test_seq 0 6 >tmp &&
		shit hash-object tmp >expect &&
		shit rev-parse B:b >>expect &&
		shit rev-parse >actual  \
			:2:b    :3:b   &&
		test_cmp expect actual &&

		# Test that the two-way merge in b is as expected
		shit cat-file -p :2:b >>ours &&
		shit cat-file -p :3:b >>theirs &&
		>empty &&
		test_must_fail shit merge-file \
			-L "HEAD" \
			-L "" \
			-L "B^0" \
			ours empty theirs &&
		test_cmp ours b
	)
'

test_expect_success 'handle rename-with-content-merge vs. add, merge other way' '
	test_setup_rename_with_content_merge_and_add BA &&
	(
		cd rename-with-content-merge-and-add-BA &&

		shit reset --hard &&
		shit clean -fdx &&

		shit checkout B^0 &&

		test_must_fail shit merge -s recursive A^0 >out &&
		test_grep "CONFLICT (.*/add)" out &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		# Also, make sure both unmerged entries are for "b"
		shit ls-files -u b >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_missing a &&
		test_path_is_file b &&

		test_seq 0 6 >tmp &&
		shit rev-parse B:b >expect &&
		shit hash-object tmp >>expect &&
		shit rev-parse >actual  \
			:2:b    :3:b   &&
		test_cmp expect actual &&

		# Test that the two-way merge in b is as expected
		shit cat-file -p :2:b >>ours &&
		shit cat-file -p :3:b >>theirs &&
		>empty &&
		test_must_fail shit merge-file \
			-L "HEAD" \
			-L "" \
			-L "A^0" \
			ours empty theirs &&
		test_cmp ours b
	)
'

# Test for all kinds of things that can go wrong with rename/rename (2to1):
#   Commit A: new files: a & b
#   Commit B: rename a->c, modify b
#   Commit C: rename b->c, modify a
#
# Merging of B & C should NOT be clean.  Questions:
#   * Both a & b should be removed by the merge; are they?
#   * The two c's should contain modifications to a & b; do they?
#   * The index should contain two files, both for c; does it?
#   * The working copy should have two files, both of form c~<unique>; does it?
#   * Nothing else should be present.  Is anything?

test_setup_rename_rename_2to1 () {
	shit init rename-rename-2to1 &&
	(
		cd rename-rename-2to1 &&

		printf "1\n2\n3\n4\n5\n" >a &&
		printf "5\n4\n3\n2\n1\n" >b &&
		shit add a b &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a c &&
		echo 0 >>b &&
		shit add b &&
		shit commit -m B &&

		shit checkout -b C A &&
		shit mv b c &&
		echo 6 >>a &&
		shit add a &&
		shit commit -m C
	)
}

test_expect_success 'handle rename/rename (2to1) conflict correctly' '
	test_setup_rename_rename_2to1 &&
	(
		cd rename-rename-2to1 &&

		shit checkout B^0 &&

		test_must_fail shit merge -s recursive C^0 >out &&
		test_grep "CONFLICT (\(.*\)/\1)" out &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		shit ls-files -u c >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_missing a &&
		test_path_is_missing b &&

		shit rev-parse >expect  \
			C:a     B:b    &&
		shit rev-parse >actual  \
			:2:c    :3:c   &&
		test_cmp expect actual &&

		# Test that the two-way merge in new_a is as expected
		shit cat-file -p :2:c >>ours &&
		shit cat-file -p :3:c >>theirs &&
		>empty &&
		test_must_fail shit merge-file \
			-L "HEAD" \
			-L "" \
			-L "C^0" \
			ours empty theirs &&
		shit hash-object c >actual &&
		shit hash-object ours >expect &&
		test_cmp expect actual
	)
'

# Testcase setup for simple rename/rename (1to2) conflict:
#   Commit A: new file: a
#   Commit B: rename a->b
#   Commit C: rename a->c
test_setup_rename_rename_1to2 () {
	shit init rename-rename-1to2 &&
	(
		cd rename-rename-1to2 &&

		echo stuff >a &&
		shit add a &&
		test_tick &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a b &&
		test_tick &&
		shit commit -m B &&

		shit checkout -b C A &&
		shit mv a c &&
		test_tick &&
		shit commit -m C
	)
}

test_expect_success 'merge has correct working tree contents' '
	test_setup_rename_rename_1to2 &&
	(
		cd rename-rename-1to2 &&

		shit checkout C^0 &&

		test_must_fail shit merge -s recursive B^0 &&

		shit ls-files -s >out &&
		test_line_count = 3 out &&
		shit ls-files -u >out &&
		test_line_count = 3 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		test_path_is_missing a &&
		shit rev-parse >expect   \
			A:a   A:a   A:a \
			A:a   A:a       &&
		shit rev-parse >actual    \
			:1:a  :3:b  :2:c &&
		shit hash-object >>actual \
			b     c          &&
		test_cmp expect actual
	)
'

# Testcase setup for rename/rename(1to2)/add-source conflict:
#   Commit A: new file: a
#   Commit B: rename a->b
#   Commit C: rename a->c, add completely different a
#
# Merging of B & C should NOT be clean; there's a rename/rename conflict

test_setup_rename_rename_1to2_add_source_1 () {
	shit init rename-rename-1to2-add-source-1 &&
	(
		cd rename-rename-1to2-add-source-1 &&

		printf "1\n2\n3\n4\n5\n6\n7\n" >a &&
		shit add a &&
		shit commit -m A &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a b &&
		shit commit -m B &&

		shit checkout -b C A &&
		shit mv a c &&
		echo something completely different >a &&
		shit add a &&
		shit commit -m C
	)
}

test_expect_failure 'detect conflict with rename/rename(1to2)/add-source merge' '
	test_setup_rename_rename_1to2_add_source_1 &&
	(
		cd rename-rename-1to2-add-source-1 &&

		shit checkout B^0 &&

		test_must_fail shit merge -s recursive C^0 &&

		shit ls-files -s >out &&
		test_line_count = 4 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		shit rev-parse >expect         \
			C:a   A:a   B:b   C:C &&
		shit rev-parse >actual          \
			:3:a  :1:a  :2:b  :3:c &&
		test_cmp expect actual &&

		test_path_is_file a &&
		test_path_is_file b &&
		test_path_is_file c
	)
'

test_setup_rename_rename_1to2_add_source_2 () {
	shit init rename-rename-1to2-add-source-2 &&
	(
		cd rename-rename-1to2-add-source-2 &&

		>a &&
		shit add a &&
		test_tick &&
		shit commit -m base &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a b &&
		test_tick &&
		shit commit -m one &&

		shit checkout -b C A &&
		shit mv a b &&
		echo important-info >a &&
		shit add a &&
		test_tick &&
		shit commit -m two
	)
}

test_expect_failure 'rename/rename/add-source still tracks new a file' '
	test_setup_rename_rename_1to2_add_source_2 &&
	(
		cd rename-rename-1to2-add-source-2 &&

		shit checkout C^0 &&
		shit merge -s recursive B^0 &&

		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		shit rev-parse >expect \
			C:a   A:a     &&
		shit rev-parse >actual \
			:0:a  :0:b    &&
		test_cmp expect actual
	)
'

test_setup_rename_rename_1to2_add_dest () {
	shit init rename-rename-1to2-add-dest &&
	(
		cd rename-rename-1to2-add-dest &&

		echo stuff >a &&
		shit add a &&
		test_tick &&
		shit commit -m base &&
		shit tag A &&

		shit checkout -b B A &&
		shit mv a b &&
		echo precious-data >c &&
		shit add c &&
		test_tick &&
		shit commit -m one &&

		shit checkout -b C A &&
		shit mv a c &&
		echo important-info >b &&
		shit add b &&
		test_tick &&
		shit commit -m two
	)
}

test_expect_success 'rename/rename/add-dest merge still knows about conflicting file versions' '
	test_setup_rename_rename_1to2_add_dest &&
	(
		cd rename-rename-1to2-add-dest &&

		shit checkout C^0 &&
		test_must_fail shit merge -s recursive B^0 &&

		shit ls-files -s >out &&
		test_line_count = 5 out &&
		shit ls-files -u b >out &&
		test_line_count = 2 out &&
		shit ls-files -u c >out &&
		test_line_count = 2 out &&
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		shit rev-parse >expect               \
			A:a   C:b   B:b   C:c   B:c &&
		shit rev-parse >actual                \
			:1:a  :2:b  :3:b  :2:c  :3:c &&
		test_cmp expect actual &&

		# Record some contents for re-doing merges
		shit cat-file -p A:a >stuff &&
		shit cat-file -p C:b >important_info &&
		shit cat-file -p B:c >precious_data &&
		>empty &&

		# Test the merge in b
		test_must_fail shit merge-file \
			-L "HEAD" \
			-L "" \
			-L "B^0" \
			important_info empty stuff &&
		test_cmp important_info b &&

		# Test the merge in c
		test_must_fail shit merge-file \
			-L "HEAD" \
			-L "" \
			-L "B^0" \
			stuff empty precious_data &&
		test_cmp stuff c
	)
'

# Testcase rad, rename/add/delete
#   Commit O: foo
#   Commit A: rm foo, add different bar
#   Commit B: rename foo->bar
#   Expected: CONFLICT (rename/add/delete), two-way merged bar

test_setup_rad () {
	shit init rad &&
	(
		cd rad &&
		echo "original file" >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit rm foo &&
		echo "different file" >bar &&
		shit add bar &&
		shit commit -m "Remove foo, add bar" &&

		shit checkout B &&
		shit mv foo bar &&
		shit commit -m "rename foo to bar"
	)
}

test_expect_merge_algorithm failure success 'rad-check: rename/add/delete conflict' '
	test_setup_rad &&
	(
		cd rad &&

		shit checkout B^0 &&
		test_must_fail shit merge -s recursive A^0 >out 2>err &&

		# Instead of requiring the output to contain one combined line
		#   CONFLICT (rename/add/delete)
		# or perhaps two lines:
		#   CONFLICT (rename/add): new file collides with rename target
		#   CONFLICT (rename/delete): rename source removed on other side
		# and instead of requiring "rename/add" instead of "add/add",
		# be flexible in the type of console output message(s) reported
		# for this particular case; we will be more stringent about the
		# contents of the index and working directory.
		test_grep "CONFLICT (.*/add)" out &&
		test_grep "CONFLICT (rename.*/delete)" out &&
		test_must_be_empty err &&

		shit ls-files -s >file_count &&
		test_line_count = 2 file_count &&
		shit ls-files -u >file_count &&
		test_line_count = 2 file_count &&
		shit ls-files -o >file_count &&
		test_line_count = 3 file_count &&

		shit rev-parse >actual \
			:2:bar :3:bar &&
		shit rev-parse >expect \
			B:bar  A:bar  &&

		test_path_is_missing foo &&
		# bar should have two-way merged contents of the different
		# versions of bar; check that content from both sides is
		# present.
		grep original bar &&
		grep different bar
	)
'

# Testcase rrdd, rename/rename(2to1)/delete/delete
#   Commit O: foo, bar
#   Commit A: rename foo->baz, rm bar
#   Commit B: rename bar->baz, rm foo
#   Expected: CONFLICT (rename/rename/delete/delete), two-way merged baz

test_setup_rrdd () {
	shit init rrdd &&
	(
		cd rrdd &&
		echo foo >foo &&
		echo bar >bar &&
		shit add foo bar &&
		shit commit -m O &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit mv foo baz &&
		shit rm bar &&
		shit commit -m "Rename foo, remove bar" &&

		shit checkout B &&
		shit mv bar baz &&
		shit rm foo &&
		shit commit -m "Rename bar, remove foo"
	)
}

test_expect_merge_algorithm failure success 'rrdd-check: rename/rename(2to1)/delete/delete conflict' '
	test_setup_rrdd &&
	(
		cd rrdd &&

		shit checkout A^0 &&
		test_must_fail shit merge -s recursive B^0 >out 2>err &&

		# Instead of requiring the output to contain one combined line
		#   CONFLICT (rename/rename/delete/delete)
		# or perhaps two lines:
		#   CONFLICT (rename/rename): ...
		#   CONFLICT (rename/delete): info about pair 1
		#   CONFLICT (rename/delete): info about pair 2
		# and instead of requiring "rename/rename" instead of "add/add",
		# be flexible in the type of console output message(s) reported
		# for this particular case; we will be more stringent about the
		# contents of the index and working directory.
		test_grep "CONFLICT (\(.*\)/\1)" out &&
		test_grep "CONFLICT (rename.*delete)" out &&
		test_must_be_empty err &&

		shit ls-files -s >file_count &&
		test_line_count = 2 file_count &&
		shit ls-files -u >file_count &&
		test_line_count = 2 file_count &&
		shit ls-files -o >file_count &&
		test_line_count = 3 file_count &&

		shit rev-parse >actual \
			:2:baz :3:baz &&
		shit rev-parse >expect \
			O:foo  O:bar  &&

		test_path_is_missing foo &&
		test_path_is_missing bar &&
		# baz should have two-way merged contents of the original
		# contents of foo and bar; check that content from both sides
		# is present.
		grep foo baz &&
		grep bar baz
	)
'

# Testcase mod6, chains of rename/rename(1to2) and rename/rename(2to1)
#   Commit O: one,      three,       five
#   Commit A: one->two, three->four, five->six
#   Commit B: one->six, three->two,  five->four
#   Expected: six CONFLICT(rename/rename) messages, each path in two of the
#             multi-way merged contents found in two, four, six

test_setup_mod6 () {
	shit init mod6 &&
	(
		cd mod6 &&
		test_seq 11 19 >one &&
		test_seq 31 39 >three &&
		test_seq 51 59 >five &&
		shit add . &&
		test_tick &&
		shit commit -m "O" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_seq 10 19 >one &&
		echo 40        >>three &&
		shit add one three &&
		shit mv  one   two  &&
		shit mv  three four &&
		shit mv  five  six  &&
		test_tick &&
		shit commit -m "A" &&

		shit checkout B &&
		echo 20    >>one       &&
		echo forty >>three     &&
		echo 60    >>five      &&
		shit add one three five &&
		shit mv  one   six  &&
		shit mv  three two  &&
		shit mv  five  four &&
		test_tick &&
		shit commit -m "B"
	)
}

test_expect_merge_algorithm failure success 'mod6-check: chains of rename/rename(1to2) and rename/rename(2to1)' '
	test_setup_mod6 &&
	(
		cd mod6 &&

		shit checkout A^0 &&

		test_must_fail shit merge -s recursive B^0 >out 2>err &&

		test_grep "CONFLICT (rename/rename)" out &&
		test_must_be_empty err &&

		shit ls-files -s >file_count &&
		test_line_count = 9 file_count &&
		shit ls-files -u >file_count &&
		test_line_count = 9 file_count &&
		shit ls-files -o >file_count &&
		test_line_count = 3 file_count &&

		test_seq 10 20 >merged-one &&
		test_seq 51 60 >merged-five &&
		# Determine what the merge of three would give us.
		test_seq 31 39 >three-base &&
		test_seq 31 40 >three-side-A &&
		test_seq 31 39 >three-side-B &&
		echo forty >>three-side-B &&
		test_must_fail shit merge-file \
			-L "HEAD:four" \
			-L "" \
			-L "B^0:two" \
			three-side-A three-base three-side-B &&
		sed -e "s/^\([<=>]\)/\1\1/" three-side-A >merged-three &&

		# Verify the index is as expected
		shit rev-parse >actual         \
			:2:two       :3:two   \
			:2:four      :3:four  \
			:2:six       :3:six   &&
		shit hash-object >expect           \
			merged-one   merged-three \
			merged-three merged-five  \
			merged-five  merged-one   &&
		test_cmp expect actual &&

		shit cat-file -p :2:two >expect &&
		shit cat-file -p :3:two >other &&
		>empty &&
		test_must_fail shit merge-file    \
			-L "HEAD"  -L ""  -L "B^0" \
			expect     empty  other &&
		test_cmp expect two &&

		shit cat-file -p :2:four >expect &&
		shit cat-file -p :3:four >other &&
		test_must_fail shit merge-file    \
			-L "HEAD"  -L ""  -L "B^0" \
			expect     empty  other &&
		test_cmp expect four &&

		shit cat-file -p :2:six >expect &&
		shit cat-file -p :3:six >other &&
		test_must_fail shit merge-file    \
			-L "HEAD"  -L ""  -L "B^0" \
			expect     empty  other &&
		test_cmp expect six
	)
'

test_conflicts_with_adds_and_renames() {
	sideL=$1
	sideR=$2

	# Setup:
	#          L
	#         / \
	#     main   ?
	#         \ /
	#          R
	#
	# Where:
	#   Both L and R have files named 'three' which collide.  Each of
	#   the colliding files could have been involved in a rename, in
	#   which case there was a file named 'one' or 'two' that was
	#   modified on the opposite side of history and renamed into the
	#   collision on this side of history.
	#
	# Questions:
	#   1) The index should contain both a stage 2 and stage 3 entry
	#      for the colliding file.  Does it?
	#   2) When renames are involved, the content merges are clean, so
	#      the index should reflect the content merges, not merely the
	#      version of the colliding file from the prior commit.  Does
	#      it?
	#   3) There should be a file in the worktree named 'three'
	#      containing the two-way merged contents of the content-merged
	#      versions of 'three' from each of the two colliding
	#      files.  Is it present?
	#   4) There should not be any three~* files in the working
	#      tree
	test_setup_collision_conflict () {
		shit init simple_${sideL}_${sideR} &&
		(
			cd simple_${sideL}_${sideR} &&

			# Create some related files now
			for i in $(test_seq 1 10)
			do
				echo Random base content line $i
			done >file_v1 &&
			cp file_v1 file_v2 &&
			echo modification >>file_v2 &&

			cp file_v1 file_v3 &&
			echo more stuff >>file_v3 &&
			cp file_v3 file_v4 &&
			echo yet more stuff >>file_v4 &&

			# Use a tag to record both these files for simple
			# access, and clean out these untracked files
			shit tag file_v1 $(shit hash-object -w file_v1) &&
			shit tag file_v2 $(shit hash-object -w file_v2) &&
			shit tag file_v3 $(shit hash-object -w file_v3) &&
			shit tag file_v4 $(shit hash-object -w file_v4) &&
			shit clean -f &&

			# Setup original commit (or merge-base), consisting of
			# files named "one" and "two" if renames were involved.
			touch irrelevant_file &&
			shit add irrelevant_file &&
			if [ $sideL = "rename" ]
			then
				shit show file_v1 >one &&
				shit add one
			fi &&
			if [ $sideR = "rename" ]
			then
				shit show file_v3 >two &&
				shit add two
			fi &&
			test_tick && shit commit -m initial &&

			shit branch L &&
			shit branch R &&

			# Handle the left side
			shit checkout L &&
			if [ $sideL = "rename" ]
			then
				shit mv one three
			else
				shit show file_v2 >three &&
				shit add three
			fi &&
			if [ $sideR = "rename" ]
			then
				shit show file_v4 >two &&
				shit add two
			fi &&
			test_tick && shit commit -m L &&

			# Handle the right side
			shit checkout R &&
			if [ $sideL = "rename" ]
			then
				shit show file_v2 >one &&
				shit add one
			fi &&
			if [ $sideR = "rename" ]
			then
				shit mv two three
			else
				shit show file_v4 >three &&
				shit add three
			fi &&
			test_tick && shit commit -m R
		)
	}

	test_expect_success "check simple $sideL/$sideR conflict" '
		test_setup_collision_conflict &&
		(
			cd simple_${sideL}_${sideR} &&

			shit checkout L^0 &&

			# Merge must fail; there is a conflict
			test_must_fail shit merge -s recursive R^0 &&

			# Make sure the index has the right number of entries
			shit ls-files -s >out &&
			test_line_count = 3 out &&
			shit ls-files -u >out &&
			test_line_count = 2 out &&
			# Ensure we have the correct number of untracked files
			shit ls-files -o >out &&
			test_line_count = 1 out &&

			# Nothing should have touched irrelevant_file
			shit rev-parse >actual      \
				:0:irrelevant_file \
				:2:three           \
				:3:three           &&
			shit rev-parse >expected        \
				main:irrelevant_file \
				file_v2                \
				file_v4                &&
			test_cmp expected actual &&

			# Make sure we have the correct merged contents for
			# three
			shit show file_v1 >expected &&
			cat <<-\EOF >>expected &&
			<<<<<<< HEAD
			modification
			=======
			more stuff
			yet more stuff
			>>>>>>> R^0
			EOF

			test_cmp expected three
		)
	'
}

test_conflicts_with_adds_and_renames rename rename
test_conflicts_with_adds_and_renames rename add
test_conflicts_with_adds_and_renames add    rename
test_conflicts_with_adds_and_renames add    add

# Setup:
#          L
#         / \
#     main   ?
#         \ /
#          R
#
# Where:
#   main has two files, named 'one' and 'two'.
#   branches L and R both modify 'one', in conflicting ways.
#   branches L and R both modify 'two', in conflicting ways.
#   branch L also renames 'one' to 'three'.
#   branch R also renames 'two' to 'three'.
#
#   So, we have four different conflicting files that all end up at path
#   'three'.
test_setup_nested_conflicts_from_rename_rename () {
	shit init nested_conflicts_from_rename_rename &&
	(
		cd nested_conflicts_from_rename_rename &&

		# Create some related files now
		for i in $(test_seq 1 10)
		do
			echo Random base content line $i
		done >file_v1 &&

		cp file_v1 file_v2 &&
		cp file_v1 file_v3 &&
		cp file_v1 file_v4 &&
		cp file_v1 file_v5 &&
		cp file_v1 file_v6 &&

		echo one  >>file_v1 &&
		echo uno  >>file_v2 &&
		echo eins >>file_v3 &&

		echo two  >>file_v4 &&
		echo dos  >>file_v5 &&
		echo zwei >>file_v6 &&

		# Setup original commit (or merge-base), consisting of
		# files named "one" and "two".
		mv file_v1 one &&
		mv file_v4 two &&
		shit add one two &&
		test_tick && shit commit -m english &&

		shit branch L &&
		shit branch R &&

		# Handle the left side
		shit checkout L &&
		shit rm one two &&
		mv -f file_v2 three &&
		mv -f file_v5 two &&
		shit add two three &&
		test_tick && shit commit -m spanish &&

		# Handle the right side
		shit checkout R &&
		shit rm one two &&
		mv -f file_v3 one &&
		mv -f file_v6 three &&
		shit add one three &&
		test_tick && shit commit -m german
	)
}

test_expect_success 'check nested conflicts from rename/rename(2to1)' '
	test_setup_nested_conflicts_from_rename_rename &&
	(
		cd nested_conflicts_from_rename_rename &&

		shit checkout L^0 &&

		# Merge must fail; there is a conflict
		test_must_fail shit merge -s recursive R^0 &&

		# Make sure the index has the right number of entries
		shit ls-files -s >out &&
		test_line_count = 2 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&
		# Ensure we have the correct number of untracked files
		shit ls-files -o >out &&
		test_line_count = 1 out &&

		# Compare :2:three to expected values
		shit cat-file -p main:one >base &&
		shit cat-file -p L:three >ours &&
		shit cat-file -p R:one >theirs &&
		test_must_fail shit merge-file    \
			-L "HEAD:three"  -L ""  -L "R^0:one" \
			ours             base   theirs &&
		sed -e "s/^\([<=>]\)/\1\1/" ours >L-three &&
		shit cat-file -p :2:three >expect &&
		test_cmp expect L-three &&

		# Compare :2:three to expected values
		shit cat-file -p main:two >base &&
		shit cat-file -p L:two >ours &&
		shit cat-file -p R:three >theirs &&
		test_must_fail shit merge-file    \
			-L "HEAD:two"  -L ""  -L "R^0:three" \
			ours           base   theirs &&
		sed -e "s/^\([<=>]\)/\1\1/" ours >R-three &&
		shit cat-file -p :3:three >expect &&
		test_cmp expect R-three &&

		# Compare three to expected contents
		>empty &&
		test_must_fail shit merge-file    \
			-L "HEAD"  -L ""  -L "R^0" \
			L-three    empty  R-three &&
		test_cmp three L-three
	)
'

# Testcase rename/rename(1to2) of a binary file
#   Commit O: orig
#   Commit A: orig-A
#   Commit B: orig-B
#   Expected: CONFLICT(rename/rename) message, three unstaged entries in the
#             index, and contents of orig-[AB] at path orig-[AB]
test_setup_rename_rename_1_to_2_binary () {
	shit init rename_rename_1_to_2_binary &&
	(
		cd rename_rename_1_to_2_binary &&

		echo '* binary' >.shitattributes &&
		shit add .shitattributes &&

		test_seq 1 10 >orig &&
		shit add orig &&
		shit commit -m orig &&

		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit mv orig orig-A &&
		test_seq 1 11 >orig-A &&
		shit add orig-A &&
		shit commit -m orig-A &&

		shit checkout B &&
		shit mv orig orig-B &&
		test_seq 0 10 >orig-B &&
		shit add orig-B &&
		shit commit -m orig-B

	)
}

test_expect_success 'rename/rename(1to2) with a binary file' '
	test_setup_rename_rename_1_to_2_binary &&
	(
		cd rename_rename_1_to_2_binary &&

		shit checkout A^0 &&

		test_must_fail shit merge -s recursive B^0 &&

		# Make sure the index has the right number of entries
		shit ls-files -s >actual &&
		test_line_count = 4 actual &&

		shit rev-parse A:orig-A B:orig-B >expect &&
		shit hash-object orig-A orig-B >actual &&
		test_cmp expect actual
	)
'

test_done
