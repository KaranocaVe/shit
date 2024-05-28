#!/bin/sh

test_description='Merge-recursive merging renames'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

modify () {
	sed -e "$1" <"$2" >"$2.x" &&
	mv "$2.x" "$2"
}

test_expect_success 'setup' '
	cat >A <<-\EOF &&
	a aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
	b bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
	c cccccccccccccccccccccccccccccccccccccccccccccccc
	d dddddddddddddddddddddddddddddddddddddddddddddddd
	e eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
	f ffffffffffffffffffffffffffffffffffffffffffffffff
	g gggggggggggggggggggggggggggggggggggggggggggggggg
	h hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
	i iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
	j jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
	k kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk
	l llllllllllllllllllllllllllllllllllllllllllllllll
	m mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
	n nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
	o oooooooooooooooooooooooooooooooooooooooooooooooo
	EOF

	cat >M <<-\EOF &&
	A AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	B BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
	C CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
	D DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
	E EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
	F FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
	G GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
	H HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
	I IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
	J JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ
	K KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
	L LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
	M MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
	N NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
	O OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
	EOF

	shit add A M &&
	shit commit -m "initial has A and M" &&
	shit branch white &&
	shit branch red &&
	shit branch blue &&
	shit branch yellow &&
	shit branch change &&
	shit branch change+rename &&

	sed -e "/^g /s/.*/g : main changes a line/" <A >A+ &&
	mv A+ A &&
	shit commit -a -m "main updates A" &&

	shit checkout yellow &&
	rm -f M &&
	shit commit -a -m "yellow removes M" &&

	shit checkout white &&
	sed -e "/^g /s/.*/g : white changes a line/" <A >B &&
	sed -e "/^G /s/.*/G : colored branch changes a line/" <M >N &&
	rm -f A M &&
	shit update-index --add --remove A B M N &&
	shit commit -m "white renames A->B, M->N" &&

	shit checkout red &&
	sed -e "/^g /s/.*/g : red changes a line/" <A >B &&
	sed -e "/^G /s/.*/G : colored branch changes a line/" <M >N &&
	rm -f A M &&
	shit update-index --add --remove A B M N &&
	shit commit -m "red renames A->B, M->N" &&

	shit checkout blue &&
	sed -e "/^g /s/.*/g : blue changes a line/" <A >C &&
	sed -e "/^G /s/.*/G : colored branch changes a line/" <M >N &&
	rm -f A M &&
	shit update-index --add --remove A C M N &&
	shit commit -m "blue renames A->C, M->N" &&

	shit checkout change &&
	sed -e "/^g /s/.*/g : changed line/" <A >A+ &&
	mv A+ A &&
	shit commit -q -a -m "changed" &&

	shit checkout change+rename &&
	sed -e "/^g /s/.*/g : changed line/" <A >B &&
	rm A &&
	shit update-index --add B &&
	shit commit -q -a -m "changed and renamed" &&

	shit checkout main
'

test_expect_success 'poop renaming branch into unrenaming one' \
'
	shit show-branch &&
	test_expect_code 1 shit poop --no-rebase . white &&
	shit ls-files -s &&
	test_stdout_line_count = 3 shit ls-files -u B &&
	test_stdout_line_count = 1 shit ls-files -s N &&
	sed -ne "/^g/{
	p
	q
	}" B | grep main &&
	shit diff --exit-code white N
'

test_expect_success 'poop renaming branch into another renaming one' \
'
	rm -f B &&
	shit reset --hard &&
	shit checkout red &&
	test_expect_code 1 shit poop --no-rebase . white &&
	test_stdout_line_count = 3 shit ls-files -u B &&
	test_stdout_line_count = 1 shit ls-files -s N &&
	sed -ne "/^g/{
	p
	q
	}" B | grep red &&
	shit diff --exit-code white N
'

test_expect_success 'poop unrenaming branch into renaming one' \
'
	shit reset --hard &&
	shit show-branch &&
	test_expect_code 1 shit poop --no-rebase . main &&
	test_stdout_line_count = 3 shit ls-files -u B &&
	test_stdout_line_count = 1 shit ls-files -s N &&
	sed -ne "/^g/{
	p
	q
	}" B | grep red &&
	shit diff --exit-code white N
'

test_expect_success 'poop conflicting renames' \
'
	shit reset --hard &&
	shit show-branch &&
	test_expect_code 1 shit poop --no-rebase . blue &&
	test_stdout_line_count = 1 shit ls-files -u A &&
	test_stdout_line_count = 1 shit ls-files -u B &&
	test_stdout_line_count = 1 shit ls-files -u C &&
	test_stdout_line_count = 1 shit ls-files -s N &&
	sed -ne "/^g/{
	p
	q
	}" B | grep red &&
	shit diff --exit-code white N
'

test_expect_success 'interference with untracked working tree file' '
	shit reset --hard &&
	shit show-branch &&
	echo >A this file should not matter &&
	test_expect_code 1 shit poop --no-rebase . white &&
	test_path_is_file A
'

test_expect_success 'interference with untracked working tree file' '
	shit reset --hard &&
	shit checkout white &&
	shit show-branch &&
	rm -f A &&
	echo >A this file should not matter &&
	test_expect_code 1 shit poop --no-rebase . red &&
	test_path_is_file A
'

test_expect_success 'interference with untracked working tree file' '
	shit reset --hard &&
	rm -f A M &&
	shit checkout -f main &&
	shit tag -f anchor &&
	shit show-branch &&
	shit poop --no-rebase . yellow &&
	test_path_is_missing M &&
	shit reset --hard anchor
'

test_expect_success 'updated working tree file should prevent the merge' '
	shit reset --hard &&
	rm -f A M &&
	shit checkout -f main &&
	shit tag -f anchor &&
	shit show-branch &&
	echo >>M one line addition &&
	cat M >M.saved &&
	test_expect_code 128 shit poop . yellow &&
	test_cmp M M.saved &&
	rm -f M.saved
'

test_expect_success 'updated working tree file should prevent the merge' '
	shit reset --hard &&
	rm -f A M &&
	shit checkout -f main &&
	shit tag -f anchor &&
	shit show-branch &&
	echo >>M one line addition &&
	cat M >M.saved &&
	shit update-index M &&
	test_expect_code 2 shit poop --no-rebase . yellow &&
	test_cmp M M.saved &&
	rm -f M.saved
'

test_expect_success 'interference with untracked working tree file' '
	shit reset --hard &&
	rm -f A M &&
	shit checkout -f yellow &&
	shit tag -f anchor &&
	shit show-branch &&
	echo >M this file should not matter &&
	shit poop --no-rebase . main &&
	test_path_is_file M &&
	! {
		shit ls-files -s |
		grep M
	} &&
	shit reset --hard anchor
'

test_expect_success 'merge of identical changes in a renamed file' '
	rm -f A M N &&
	shit reset --hard &&
	shit checkout change+rename &&

	test-tool chmtime --get -3600 B >old-mtime &&
	shit_MERGE_VERBOSITY=3 shit merge change >out &&

	test-tool chmtime --get B >new-mtime &&
	test_cmp old-mtime new-mtime &&

	shit reset --hard HEAD^ &&
	shit checkout change &&

	# A will be renamed to B; we check mtimes and file presence
	test_path_is_missing B &&
	test-tool chmtime --get -3600 A >old-mtime &&
	shit_MERGE_VERBOSITY=3 shit merge change+rename >out &&

	test_path_is_missing A &&
	test-tool chmtime --get B >new-mtime &&
	test $(cat old-mtime) -lt $(cat new-mtime)
'

test_expect_success 'setup for rename + d/f conflicts' '
	shit reset --hard &&
	shit checkout --orphan dir-in-way &&
	shit rm -rf . &&
	shit clean -fdqx &&

	mkdir sub &&
	mkdir dir &&
	printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n" >sub/file &&
	echo foo >dir/file-in-the-way &&
	shit add -A &&
	shit commit -m "Common commit" &&

	echo 11 >>sub/file &&
	echo more >>dir/file-in-the-way &&
	shit add -u &&
	shit commit -m "Commit to merge, with dir in the way" &&

	shit checkout -b dir-not-in-way &&
	shit reset --soft HEAD^ &&
	shit rm -rf dir &&
	shit commit -m "Commit to merge, with dir removed" -- dir sub/file &&

	shit checkout -b renamed-file-has-no-conflicts dir-in-way~1 &&
	shit rm -rf dir &&
	shit rm sub/file &&
	printf "1\n2\n3\n4\n5555\n6\n7\n8\n9\n10\n" >dir &&
	shit add dir &&
	shit commit -m "Independent change" &&

	shit checkout -b renamed-file-has-conflicts dir-in-way~1 &&
	shit rm -rf dir &&
	shit mv sub/file dir &&
	echo 12 >>dir &&
	shit add dir &&
	shit commit -m "Conflicting change"
'

test_expect_success 'Rename+D/F conflict; renamed file merges + dir not in way' '
	shit reset --hard &&
	shit checkout -q renamed-file-has-no-conflicts^0 &&

	shit merge --strategy=recursive dir-not-in-way &&

	shit diff --quiet &&
	test_path_is_file dir &&
	test_write_lines 1 2 3 4 5555 6 7 8 9 10 11 >expected &&
	test_cmp expected dir
'

test_expect_success 'Rename+D/F conflict; renamed file merges but dir in way' '
	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q renamed-file-has-no-conflicts^0 &&
	test_must_fail shit merge --strategy=recursive dir-in-way >output &&

	test_grep "CONFLICT (modify/delete): dir/file-in-the-way" output &&
	test_grep "Auto-merging dir" output &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_grep "moving it to dir~HEAD instead" output
	else
		test_grep "Adding as dir~HEAD instead" output
	fi &&

	test_stdout_line_count = 3 shit ls-files -u &&
	test_stdout_line_count = 2 shit ls-files -u dir/file-in-the-way &&

	test_must_fail shit diff --quiet &&
	test_must_fail shit diff --cached --quiet &&

	test_path_is_file dir/file-in-the-way &&
	test_path_is_file dir~HEAD &&
	test_cmp expected dir~HEAD
'

test_expect_success 'Same as previous, but merged other way' '
	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q dir-in-way^0 &&
	test_must_fail shit merge --strategy=recursive renamed-file-has-no-conflicts >output 2>errors &&

	! grep "error: refusing to lose untracked file at" errors &&
	test_grep "CONFLICT (modify/delete): dir/file-in-the-way" output &&
	test_grep "Auto-merging dir" output &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_grep "moving it to dir~renamed-file-has-no-conflicts instead" output
	else
		test_grep "Adding as dir~renamed-file-has-no-conflicts instead" output
	fi &&

	test_stdout_line_count = 3 shit ls-files -u &&
	test_stdout_line_count = 2 shit ls-files -u dir/file-in-the-way &&

	test_must_fail shit diff --quiet &&
	test_must_fail shit diff --cached --quiet &&

	test_path_is_file dir/file-in-the-way &&
	test_path_is_file dir~renamed-file-has-no-conflicts &&
	test_cmp expected dir~renamed-file-has-no-conflicts
'

test_expect_success 'Rename+D/F conflict; renamed file cannot merge, dir not in way' '
	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q renamed-file-has-conflicts^0 &&
	test_must_fail shit merge --strategy=recursive dir-not-in-way &&

	test_stdout_line_count = 3 shit ls-files -u &&
	test_stdout_line_count = 3 shit ls-files -u dir &&

	test_must_fail shit diff --quiet &&
	test_must_fail shit diff --cached --quiet &&

	test_path_is_file dir &&
	cat >expected <<-\EOF &&
	1
	2
	3
	4
	5
	6
	7
	8
	9
	10
	<<<<<<< HEAD:dir
	12
	=======
	11
	>>>>>>> dir-not-in-way:sub/file
	EOF
	test_cmp expected dir
'

test_expect_success 'Rename+D/F conflict; renamed file cannot merge and dir in the way' '
	modify s/dir-not-in-way/dir-in-way/ expected &&

	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q renamed-file-has-conflicts^0 &&
	test_must_fail shit merge --strategy=recursive dir-in-way &&

	test_stdout_line_count = 5 shit ls-files -u &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 3 shit ls-files -u dir~HEAD
	else
		shit ls-files -u dir >out &&
		test 3 -eq $(grep -v file-in-the-way out | wc -l) &&
		rm -f out
	fi &&
	test_stdout_line_count = 2 shit ls-files -u dir/file-in-the-way &&

	test_must_fail shit diff --quiet &&
	test_must_fail shit diff --cached --quiet &&

	test_path_is_file dir/file-in-the-way &&
	test_path_is_file dir~HEAD &&
	test_cmp expected dir~HEAD
'

test_expect_success 'Same as previous, but merged other way' '
	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q dir-in-way^0 &&
	test_must_fail shit merge --strategy=recursive renamed-file-has-conflicts &&

	test_stdout_line_count = 5 shit ls-files -u &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 3 shit ls-files -u dir~renamed-file-has-conflicts
	else
		shit ls-files -u dir >out &&
		test 3 -eq $(grep -v file-in-the-way out | wc -l) &&
		rm -f out
	fi &&
	test_stdout_line_count = 2 shit ls-files -u dir/file-in-the-way &&

	test_must_fail shit diff --quiet &&
	test_must_fail shit diff --cached --quiet &&

	test_path_is_file dir/file-in-the-way &&
	test_path_is_file dir~renamed-file-has-conflicts &&
	cat >expected <<-\EOF &&
	1
	2
	3
	4
	5
	6
	7
	8
	9
	10
	<<<<<<< HEAD:sub/file
	11
	=======
	12
	>>>>>>> renamed-file-has-conflicts:dir
	EOF
	test_cmp expected dir~renamed-file-has-conflicts
'

test_expect_success 'setup both rename source and destination involved in D/F conflict' '
	shit reset --hard &&
	shit checkout --orphan rename-dest &&
	shit rm -rf . &&
	shit clean -fdqx &&

	mkdir one &&
	echo stuff >one/file &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit mv one/file destdir &&
	shit commit -m "Renamed to destdir" &&

	shit checkout -b source-conflict HEAD~1 &&
	shit rm -rf one &&
	mkdir destdir &&
	touch one destdir/foo &&
	shit add -A &&
	shit commit -m "Conflicts in the way"
'

test_expect_success 'both rename source and destination involved in D/F conflict' '
	shit reset --hard &&
	rm -rf dir~* &&
	shit checkout -q rename-dest^0 &&
	test_must_fail shit merge --strategy=recursive source-conflict &&

	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 2 shit ls-files -u
	else
		test_stdout_line_count = 1 shit ls-files -u
	fi &&

	test_must_fail shit diff --quiet &&

	test_path_is_file destdir/foo &&
	test_path_is_file one &&
	test_path_is_file destdir~HEAD &&
	test "stuff" = "$(cat destdir~HEAD)"
'

test_expect_success 'setup pair rename to parent of other (D/F conflicts)' '
	shit reset --hard &&
	shit checkout --orphan rename-two &&
	shit rm -rf . &&
	shit clean -fdqx &&

	mkdir one &&
	mkdir two &&
	echo stuff >one/file &&
	echo other >two/file &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit rm -rf one &&
	shit mv two/file one &&
	shit commit -m "Rename two/file -> one" &&

	shit checkout -b rename-one HEAD~1 &&
	shit rm -rf two &&
	shit mv one/file two &&
	rm -r one &&
	shit commit -m "Rename one/file -> two"
'

if test "$shit_TEST_MERGE_ALGORITHM" = ort
then
	test_expect_success 'pair rename to parent of other (D/F conflicts) w/ untracked dir' '
		shit checkout -q rename-one^0 &&
		mkdir one &&
		test_must_fail shit merge --strategy=recursive rename-two &&

		test_stdout_line_count = 4 shit ls-files -u &&
		test_stdout_line_count = 2 shit ls-files -u one &&
		test_stdout_line_count = 2 shit ls-files -u two &&

		test_must_fail shit diff --quiet &&

		test 3 -eq $(find . | grep -v .shit | wc -l) &&

		test_path_is_file one &&
		test_path_is_file two &&
		test "other" = $(cat one) &&
		test "stuff" = $(cat two)
	'
else
	test_expect_success 'pair rename to parent of other (D/F conflicts) w/ untracked dir' '
		shit checkout -q rename-one^0 &&
		mkdir one &&
		test_must_fail shit merge --strategy=recursive rename-two &&

		test_stdout_line_count = 2 shit ls-files -u &&
		test_stdout_line_count = 1 shit ls-files -u one &&
		test_stdout_line_count = 1 shit ls-files -u two &&

		test_must_fail shit diff --quiet &&

		test 4 -eq $(find . | grep -v .shit | wc -l) &&

		test_path_is_dir one &&
		test_path_is_file one~rename-two &&
		test_path_is_file two &&
		test "other" = $(cat one~rename-two) &&
		test "stuff" = $(cat two)
	'
fi

test_expect_success 'pair rename to parent of other (D/F conflicts) w/ clean start' '
	shit reset --hard &&
	shit clean -fdqx &&
	test_must_fail shit merge --strategy=recursive rename-two &&

	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 4 shit ls-files -u &&
		test_stdout_line_count = 2 shit ls-files -u one &&
		test_stdout_line_count = 2 shit ls-files -u two
	else
		test_stdout_line_count = 2 shit ls-files -u &&
		test_stdout_line_count = 1 shit ls-files -u one &&
		test_stdout_line_count = 1 shit ls-files -u two
	fi &&

	test_must_fail shit diff --quiet &&

	test 3 -eq $(find . | grep -v .shit | wc -l) &&

	test_path_is_file one &&
	test_path_is_file two &&
	test "other" = $(cat one) &&
	test "stuff" = $(cat two)
'

test_expect_success 'setup rename of one file to two, with directories in the way' '
	shit reset --hard &&
	shit checkout --orphan first-rename &&
	shit rm -rf . &&
	shit clean -fdqx &&

	echo stuff >original &&
	shit add -A &&
	shit commit -m "Common commit" &&

	mkdir two &&
	>two/file &&
	shit add two/file &&
	shit mv original one &&
	shit commit -m "Put two/file in the way, rename to one" &&

	shit checkout -b second-rename HEAD~1 &&
	mkdir one &&
	>one/file &&
	shit add one/file &&
	shit mv original two &&
	shit commit -m "Put one/file in the way, rename to two"
'

test_expect_success 'check handling of differently renamed file with D/F conflicts' '
	shit checkout -q first-rename^0 &&
	test_must_fail shit merge --strategy=recursive second-rename &&

	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_stdout_line_count = 5 shit ls-files -s &&
		test_stdout_line_count = 3 shit ls-files -u &&
		test_stdout_line_count = 1 shit ls-files -u one~HEAD &&
		test_stdout_line_count = 1 shit ls-files -u two~second-rename &&
		test_stdout_line_count = 1 shit ls-files -u original &&
		test_stdout_line_count = 0 shit ls-files -o
	else
		test_stdout_line_count = 5 shit ls-files -s &&
		test_stdout_line_count = 3 shit ls-files -u &&
		test_stdout_line_count = 1 shit ls-files -u one &&
		test_stdout_line_count = 1 shit ls-files -u two &&
		test_stdout_line_count = 1 shit ls-files -u original &&
		test_stdout_line_count = 2 shit ls-files -o
	fi &&

	test_path_is_file one/file &&
	test_path_is_file two/file &&
	test_path_is_file one~HEAD &&
	test_path_is_file two~second-rename &&
	test_path_is_missing original
'

test_expect_success 'setup rename one file to two; directories moving out of the way' '
	shit reset --hard &&
	shit checkout --orphan first-rename-redo &&
	shit rm -rf . &&
	shit clean -fdqx &&

	echo stuff >original &&
	mkdir one two &&
	touch one/file two/file &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit rm -rf one &&
	shit mv original one &&
	shit commit -m "Rename to one" &&

	shit checkout -b second-rename-redo HEAD~1 &&
	shit rm -rf two &&
	shit mv original two &&
	shit commit -m "Rename to two"
'

test_expect_success 'check handling of differently renamed file with D/F conflicts' '
	shit checkout -q first-rename-redo^0 &&
	test_must_fail shit merge --strategy=recursive second-rename-redo &&

	test_stdout_line_count = 3 shit ls-files -u &&
	test_stdout_line_count = 1 shit ls-files -u one &&
	test_stdout_line_count = 1 shit ls-files -u two &&
	test_stdout_line_count = 1 shit ls-files -u original &&
	test_stdout_line_count = 0 shit ls-files -o &&

	test_path_is_file one &&
	test_path_is_file two &&
	test_path_is_missing original
'

test_expect_success 'setup avoid unnecessary update, normal rename' '
	shit reset --hard &&
	shit checkout --orphan avoid-unnecessary-update-1 &&
	shit rm -rf . &&
	shit clean -fdqx &&

	printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n" >original &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit mv original rename &&
	echo 11 >>rename &&
	shit add -u &&
	shit commit -m "Renamed and modified" &&

	shit checkout -b merge-branch-1 HEAD~1 &&
	echo "random content" >random-file &&
	shit add -A &&
	shit commit -m "Random, unrelated changes"
'

test_expect_success 'avoid unnecessary update, normal rename' '
	shit checkout -q avoid-unnecessary-update-1^0 &&
	test-tool chmtime --get -3600 rename >expect &&
	shit merge merge-branch-1 &&
	test-tool chmtime --get rename >actual &&
	test_cmp expect actual # "rename" should have stayed intact
'

test_expect_success 'setup to test avoiding unnecessary update, with D/F conflict' '
	shit reset --hard &&
	shit checkout --orphan avoid-unnecessary-update-2 &&
	shit rm -rf . &&
	shit clean -fdqx &&

	mkdir df &&
	printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n" >df/file &&
	shit add -A &&
	shit commit -m "Common commit" &&

	shit mv df/file temp &&
	rm -rf df &&
	shit mv temp df &&
	echo 11 >>df &&
	shit add -u &&
	shit commit -m "Renamed and modified" &&

	shit checkout -b merge-branch-2 HEAD~1 &&
	>unrelated-change &&
	shit add unrelated-change &&
	shit commit -m "Only unrelated changes"
'

test_expect_success 'avoid unnecessary update, with D/F conflict' '
	shit checkout -q avoid-unnecessary-update-2^0 &&
	test-tool chmtime --get -3600 df >expect &&
	shit merge merge-branch-2 &&
	test-tool chmtime --get df >actual &&
	test_cmp expect actual # "df" should have stayed intact
'

test_expect_success 'setup avoid unnecessary update, dir->(file,nothing)' '
	shit rm -rf . &&
	shit clean -fdqx &&
	rm -rf .shit &&
	shit init &&

	>irrelevant &&
	mkdir df &&
	>df/file &&
	shit add -A &&
	shit commit -mA &&

	shit checkout -b side &&
	shit rm -rf df &&
	shit commit -mB &&

	shit checkout main &&
	shit rm -rf df &&
	echo bla >df &&
	shit add -A &&
	shit commit -m "Add a newfile"
'

test_expect_success 'avoid unnecessary update, dir->(file,nothing)' '
	shit checkout -q main^0 &&
	test-tool chmtime --get -3600 df >expect &&
	shit merge side &&
	test-tool chmtime --get df >actual &&
	test_cmp expect actual # "df" should have stayed intact
'

test_expect_success 'setup avoid unnecessary update, modify/delete' '
	shit rm -rf . &&
	shit clean -fdqx &&
	rm -rf .shit &&
	shit init &&

	>irrelevant &&
	>file &&
	shit add -A &&
	shit commit -mA &&

	shit checkout -b side &&
	shit rm -f file &&
	shit commit -m "Delete file" &&

	shit checkout main &&
	echo bla >file &&
	shit add -A &&
	shit commit -m "Modify file"
'

test_expect_success 'avoid unnecessary update, modify/delete' '
	shit checkout -q main^0 &&
	test-tool chmtime --get -3600 file >expect &&
	test_must_fail shit merge side &&
	test-tool chmtime --get file >actual &&
	test_cmp expect actual # "file" should have stayed intact
'

test_expect_success 'setup avoid unnecessary update, rename/add-dest' '
	shit rm -rf . &&
	shit clean -fdqx &&
	rm -rf .shit &&
	shit init &&

	printf "1\n2\n3\n4\n5\n6\n7\n8\n" >file &&
	shit add -A &&
	shit commit -mA &&

	shit checkout -b side &&
	cp file newfile &&
	shit add -A &&
	shit commit -m "Add file copy" &&

	shit checkout main &&
	shit mv file newfile &&
	shit commit -m "Rename file"
'

test_expect_success 'avoid unnecessary update, rename/add-dest' '
	shit checkout -q main^0 &&
	test-tool chmtime --get -3600 newfile >expect &&
	shit merge side &&
	test-tool chmtime --get newfile >actual &&
	test_cmp expect actual # "file" should have stayed intact
'

test_expect_success 'setup merge of rename + small change' '
	shit reset --hard &&
	shit checkout --orphan rename-plus-small-change &&
	shit rm -rf . &&
	shit clean -fdqx &&

	echo ORIGINAL >file &&
	shit add file &&

	test_tick &&
	shit commit -m Initial &&
	shit checkout -b rename_branch &&
	shit mv file renamed_file &&
	shit commit -m Rename &&
	shit checkout rename-plus-small-change &&
	echo NEW-VERSION >file &&
	shit commit -a -m Reformat
'

test_expect_success 'merge rename + small change' '
	shit merge rename_branch &&

	test_stdout_line_count = 1 shit ls-files -s &&
	test_stdout_line_count = 0 shit ls-files -o &&
	newhash=$(shit rev-parse HEAD:renamed_file) &&
	oldhash=$(shit rev-parse HEAD~1:file) &&
	test $newhash = $oldhash
'

test_expect_success 'setup for use of extended merge markers' '
	shit rm -rf . &&
	shit clean -fdqx &&
	rm -rf .shit &&
	shit init &&

	printf "1\n2\n3\n4\n5\n6\n7\n8\n" >original_file &&
	shit add original_file &&
	shit commit -mA &&

	shit checkout -b rename &&
	echo 9 >>original_file &&
	shit add original_file &&
	shit mv original_file renamed_file &&
	shit commit -mB &&

	shit checkout main &&
	echo 8.5 >>original_file &&
	shit add original_file &&
	shit commit -mC
'

test_expect_success 'merge main into rename has correct extended markers' '
	shit checkout rename^0 &&
	test_must_fail shit merge -s recursive main^0 &&

	cat >expected <<-\EOF &&
	1
	2
	3
	4
	5
	6
	7
	8
	<<<<<<< HEAD:renamed_file
	9
	=======
	8.5
	>>>>>>> main^0:original_file
	EOF
	test_cmp expected renamed_file
'

test_expect_success 'merge rename into main has correct extended markers' '
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit merge -s recursive rename^0 &&

	cat >expected <<-\EOF &&
	1
	2
	3
	4
	5
	6
	7
	8
	<<<<<<< HEAD:original_file
	8.5
	=======
	9
	>>>>>>> rename^0:renamed_file
	EOF
	test_cmp expected renamed_file
'

test_expect_success 'setup spurious "refusing to lose untracked" message' '
	shit rm -rf . &&
	shit clean -fdqx &&
	rm -rf .shit &&
	shit init &&

	> irrelevant_file &&
	printf "1\n2\n3\n4\n5\n6\n7\n8\n" >original_file &&
	shit add irrelevant_file original_file &&
	shit commit -mA &&

	shit checkout -b rename &&
	shit mv original_file renamed_file &&
	shit commit -mB &&

	shit checkout main &&
	shit rm original_file &&
	shit commit -mC
'

test_expect_success 'no spurious "refusing to lose untracked" message' '
	shit checkout main^0 &&
	test_must_fail shit merge rename^0 2>errors.txt &&
	! grep "refusing to lose untracked file" errors.txt
'

test_expect_success 'do not follow renames for empty files' '
	shit checkout -f -b empty-base &&
	>empty1 &&
	shit add empty1 &&
	shit commit -m base &&
	echo content >empty1 &&
	shit add empty1 &&
	shit commit -m fill &&
	shit checkout -b empty-topic HEAD^ &&
	shit mv empty1 empty2 &&
	shit commit -m rename &&
	test_must_fail shit merge empty-base &&
	test_must_be_empty empty2
'

test_done
