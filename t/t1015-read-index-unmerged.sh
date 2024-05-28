#!/bin/sh

test_description='Test various callers of read_index_unmerged'
. ./test-lib.sh

test_expect_success 'setup modify/delete + directory/file conflict' '
	test_create_repo df_plus_modify_delete &&
	(
		cd df_plus_modify_delete &&

		test_write_lines a b c d e f g h >letters &&
		shit add letters &&
		shit commit -m initial &&

		shit checkout -b modify &&
		# Throw in letters.txt for sorting order fun
		# ("letters.txt" sorts between "letters" and "letters/file")
		echo i >>letters &&
		echo "version 2" >letters.txt &&
		shit add letters letters.txt &&
		shit commit -m modified &&

		shit checkout -b delete HEAD^ &&
		shit rm letters &&
		mkdir letters &&
		>letters/file &&
		echo "version 1" >letters.txt &&
		shit add letters letters.txt &&
		shit commit -m deleted
	)
'

test_expect_success 'read-tree --reset cleans unmerged entries' '
	test_when_finished "shit -C df_plus_modify_delete clean -f" &&
	test_when_finished "shit -C df_plus_modify_delete reset --hard" &&
	(
		cd df_plus_modify_delete &&

		shit checkout delete^0 &&
		test_must_fail shit merge modify &&

		shit read-tree --reset HEAD &&
		shit ls-files -u >conflicts &&
		test_must_be_empty conflicts
	)
'

test_expect_success 'One reset --hard cleans unmerged entries' '
	test_when_finished "shit -C df_plus_modify_delete clean -f" &&
	test_when_finished "shit -C df_plus_modify_delete reset --hard" &&
	(
		cd df_plus_modify_delete &&

		shit checkout delete^0 &&
		test_must_fail shit merge modify &&

		shit reset --hard &&
		test_path_is_missing .shit/MERGE_HEAD &&
		shit ls-files -u >conflicts &&
		test_must_be_empty conflicts
	)
'

test_expect_success 'setup directory/file conflict + simple edit/edit' '
	test_create_repo df_plus_edit_edit &&
	(
		cd df_plus_edit_edit &&

		test_seq 1 10 >numbers &&
		shit add numbers &&
		shit commit -m initial &&

		shit checkout -b d-edit &&
		mkdir foo &&
		echo content >foo/bar &&
		shit add foo &&
		echo 11 >>numbers &&
		shit add numbers &&
		shit commit -m "directory and edit" &&

		shit checkout -b f-edit d-edit^1 &&
		echo content >foo &&
		shit add foo &&
		echo eleven >>numbers &&
		shit add numbers &&
		shit commit -m "file and edit"
	)
'

test_expect_success 'shit merge --abort succeeds despite D/F conflict' '
	test_when_finished "shit -C df_plus_edit_edit clean -f" &&
	test_when_finished "shit -C df_plus_edit_edit reset --hard" &&
	(
		cd df_plus_edit_edit &&

		shit checkout f-edit^0 &&
		test_must_fail shit merge d-edit^0 &&

		shit merge --abort &&
		test_path_is_missing .shit/MERGE_HEAD &&
		shit ls-files -u >conflicts &&
		test_must_be_empty conflicts
	)
'

test_expect_success 'shit am --skip succeeds despite D/F conflict' '
	test_when_finished "shit -C df_plus_edit_edit clean -f" &&
	test_when_finished "shit -C df_plus_edit_edit reset --hard" &&
	(
		cd df_plus_edit_edit &&

		shit checkout f-edit^0 &&
		shit format-patch -1 d-edit &&
		test_must_fail shit am -3 0001*.patch &&

		shit am --skip &&
		test_path_is_missing .shit/rebase-apply &&
		shit ls-files -u >conflicts &&
		test_must_be_empty conflicts
	)
'

test_done
