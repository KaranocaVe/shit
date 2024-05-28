#!/bin/sh

test_description='shit rebase + directory rename tests'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup testcase where directory rename should be detected' '
	test_create_repo dir-rename &&
	(
		cd dir-rename &&

		mkdir x &&
		test_seq  1 10 >x/a &&
		test_seq 11 20 >x/b &&
		test_seq 21 30 >x/c &&
		test_write_lines a b c d e f g h i >l &&
		shit add x l &&
		shit commit -m "Initial" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit mv x y &&
		shit mv l letters &&
		shit commit -m "Rename x to y, l to letters" &&

		shit checkout B &&
		echo j >>l &&
		test_seq 31 40 >x/d &&
		shit add l x/d &&
		shit commit -m "Modify l, add x/d"
	)
'

test_expect_success 'rebase --interactive: directory rename detected' '
	(
		cd dir-rename &&

		shit checkout B^0 &&

		set_fake_editor &&
		FAKE_LINES="1" shit -c merge.directoryRenames=true rebase --interactive A &&

		shit ls-files -s >out &&
		test_line_count = 5 out &&

		test_path_is_file y/d &&
		test_path_is_missing x/d
	)
'

test_expect_failure 'rebase --apply: directory rename detected' '
	(
		cd dir-rename &&

		shit checkout B^0 &&

		shit -c merge.directoryRenames=true rebase --apply A &&

		shit ls-files -s >out &&
		test_line_count = 5 out &&

		test_path_is_file y/d &&
		test_path_is_missing x/d
	)
'

test_expect_success 'rebase --merge: directory rename detected' '
	(
		cd dir-rename &&

		shit checkout B^0 &&

		shit -c merge.directoryRenames=true rebase --merge A &&

		shit ls-files -s >out &&
		test_line_count = 5 out &&

		test_path_is_file y/d &&
		test_path_is_missing x/d
	)
'

test_expect_failure 'am: directory rename detected' '
	(
		cd dir-rename &&

		shit checkout A^0 &&

		shit format-patch -1 B &&

		shit -c merge.directoryRenames=true am --3way 0001*.patch &&

		shit ls-files -s >out &&
		test_line_count = 5 out &&

		test_path_is_file y/d &&
		test_path_is_missing x/d
	)
'

test_expect_success 'setup testcase where directory rename should NOT be detected' '
	test_create_repo no-dir-rename &&
	(
		cd no-dir-rename &&

		mkdir x &&
		test_seq  1 10 >x/a &&
		test_seq 11 20 >x/b &&
		test_seq 21 30 >x/c &&
		echo original >project_info &&
		shit add x project_info &&
		shit commit -m "Initial" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		echo v2 >project_info &&
		shit add project_info &&
		shit commit -m "Modify project_info" &&

		shit checkout B &&
		mkdir y &&
		shit mv x/c y/c &&
		echo v1 >project_info &&
		shit add project_info &&
		shit commit -m "Rename x/c to y/c, modify project_info"
	)
'

test_expect_success 'rebase --interactive: NO directory rename' '
	test_when_finished "shit -C no-dir-rename rebase --abort" &&
	(
		cd no-dir-rename &&

		shit checkout B^0 &&

		set_fake_editor &&
		test_must_fail env FAKE_LINES="1" shit rebase --interactive A &&

		shit ls-files -s >out &&
		test_line_count = 6 out &&

		test_path_is_file x/a &&
		test_path_is_file x/b &&
		test_path_is_missing x/c
	)
'

test_expect_success 'rebase (am): NO directory rename' '
	test_when_finished "shit -C no-dir-rename rebase --abort" &&
	(
		cd no-dir-rename &&

		shit checkout B^0 &&

		set_fake_editor &&
		test_must_fail shit rebase A &&

		shit ls-files -s >out &&
		test_line_count = 6 out &&

		test_path_is_file x/a &&
		test_path_is_file x/b &&
		test_path_is_missing x/c
	)
'

test_expect_success 'rebase --merge: NO directory rename' '
	test_when_finished "shit -C no-dir-rename rebase --abort" &&
	(
		cd no-dir-rename &&

		shit checkout B^0 &&

		set_fake_editor &&
		test_must_fail shit rebase --merge A &&

		shit ls-files -s >out &&
		test_line_count = 6 out &&

		test_path_is_file x/a &&
		test_path_is_file x/b &&
		test_path_is_missing x/c
	)
'

test_expect_success 'am: NO directory rename' '
	test_when_finished "shit -C no-dir-rename am --abort" &&
	(
		cd no-dir-rename &&

		shit checkout A^0 &&

		shit format-patch -1 B &&

		test_must_fail shit am --3way 0001*.patch &&

		shit ls-files -s >out &&
		test_line_count = 6 out &&

		test_path_is_file x/a &&
		test_path_is_file x/b &&
		test_path_is_missing x/c
	)
'

test_done
