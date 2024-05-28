#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='Test rename detection in diff engine.

'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff.sh

test_expect_success 'setup' '
	cat >path0 <<-\EOF &&
	Line 1
	Line 2
	Line 3
	Line 4
	Line 5
	Line 6
	Line 7
	Line 8
	Line 9
	Line 10
	line 11
	Line 12
	Line 13
	Line 14
	Line 15
	EOF
	cat >expected <<-\EOF &&
	diff --shit a/path0 b/path1
	rename from path0
	rename to path1
	--- a/path0
	+++ b/path1
	@@ -8,7 +8,7 @@ Line 7
	 Line 8
	 Line 9
	 Line 10
	-line 11
	+Line 11
	 Line 12
	 Line 13
	 Line 14
	EOF
	cat >no-rename <<-\EOF
	diff --shit a/path0 b/path0
	deleted file mode 100644
	index fdbec44..0000000
	--- a/path0
	+++ /dev/null
	@@ -1,15 +0,0 @@
	-Line 1
	-Line 2
	-Line 3
	-Line 4
	-Line 5
	-Line 6
	-Line 7
	-Line 8
	-Line 9
	-Line 10
	-line 11
	-Line 12
	-Line 13
	-Line 14
	-Line 15
	diff --shit a/path1 b/path1
	new file mode 100644
	index 0000000..752c50e
	--- /dev/null
	+++ b/path1
	@@ -0,0 +1,15 @@
	+Line 1
	+Line 2
	+Line 3
	+Line 4
	+Line 5
	+Line 6
	+Line 7
	+Line 8
	+Line 9
	+Line 10
	+Line 11
	+Line 12
	+Line 13
	+Line 14
	+Line 15
	EOF
'

test_expect_success \
    'update-index --add a file.' \
    'shit update-index --add path0'

test_expect_success \
    'write that tree.' \
    'tree=$(shit write-tree) && echo $tree'

sed -e 's/line/Line/' <path0 >path1
rm -f path0
test_expect_success \
    'renamed and edited the file.' \
    'shit update-index --add --remove path0 path1'

test_expect_success \
    'shit diff-index -p -M after rename and editing.' \
    'shit diff-index -p -M $tree >current'


test_expect_success \
    'validate the output.' \
    'compare_diff_patch current expected'

test_expect_success 'test diff.renames=true' '
	shit -c diff.renames=true diff --cached $tree >current &&
	compare_diff_patch current expected
'

test_expect_success 'test diff.renames=false' '
	shit -c diff.renames=false diff --cached $tree >current &&
	compare_diff_patch current no-rename
'

test_expect_success 'test diff.renames unset' '
	shit diff --cached $tree >current &&
	compare_diff_patch current expected
'

test_expect_success 'favour same basenames over different ones' '
	cp path1 another-path &&
	shit add another-path &&
	shit commit -m 1 &&
	shit rm path1 &&
	mkdir subdir &&
	shit mv another-path subdir/path1 &&
	shit status >out &&
	test_grep "renamed: .*path1 -> subdir/path1" out
'

test_expect_success 'test diff.renames=true for shit status' '
	shit -c diff.renames=true status >out &&
	test_grep "renamed: .*path1 -> subdir/path1" out
'

test_expect_success 'test diff.renames=false for shit status' '
	shit -c diff.renames=false status >out &&
	test_grep ! "renamed: .*path1 -> subdir/path1" out &&
	test_grep "new file: .*subdir/path1" out &&
	test_grep "deleted: .*[^/]path1" out
'

test_expect_success 'favour same basenames even with minor differences' '
	shit show HEAD:path1 | sed "s/15/16/" > subdir/path1 &&
	shit status >out &&
	test_grep "renamed: .*path1 -> subdir/path1" out
'

test_expect_success 'two files with same basename and same content' '
	shit reset --hard &&
	mkdir -p dir/A dir/B &&
	cp path1 dir/A/file &&
	cp path1 dir/B/file &&
	shit add dir &&
	shit commit -m 2 &&
	shit mv dir other-dir &&
	shit status >out &&
	test_grep "renamed: .*dir/A/file -> other-dir/A/file" out
'

test_expect_success 'setup for many rename source candidates' '
	shit reset --hard &&
	for i in 0 1 2 3 4 5 6 7 8 9;
	do
		for j in 0 1 2 3 4 5 6 7 8 9;
		do
			echo "$i$j" >"path$i$j" || return 1
		done
	done &&
	shit add "path??" &&
	test_tick &&
	shit commit -m "hundred" &&
	(cat path1 && echo new) >new-path &&
	echo old >>path1 &&
	shit add new-path path1 &&
	shit diff -l 4 -C -C --cached --name-status >actual 2>actual.err &&
	sed -e "s/^\([CM]\)[0-9]*	/\1	/" actual >actual.munged &&
	cat >expect <<-EOF &&
	C	path1	new-path
	M	path1
	EOF
	test_cmp expect actual.munged &&
	grep warning actual.err
'

test_expect_success 'rename pretty print with nothing in common' '
	mkdir -p a/b/ &&
	: >a/b/c &&
	shit add a/b/c &&
	shit commit -m "create a/b/c" &&
	mkdir -p c/b/ &&
	shit mv a/b/c c/b/a &&
	shit commit -m "a/b/c -> c/b/a" &&
	shit diff -M --summary HEAD^ HEAD >output &&
	test_grep " a/b/c => c/b/a " output &&
	shit diff -M --stat HEAD^ HEAD >output &&
	test_grep " a/b/c => c/b/a " output
'

test_expect_success 'rename pretty print with common prefix' '
	mkdir -p c/d &&
	shit mv c/b/a c/d/e &&
	shit commit -m "c/b/a -> c/d/e" &&
	shit diff -M --summary HEAD^ HEAD >output &&
	test_grep " c/{b/a => d/e} " output &&
	shit diff -M --stat HEAD^ HEAD >output &&
	test_grep " c/{b/a => d/e} " output
'

test_expect_success 'rename pretty print with common suffix' '
	mkdir d &&
	shit mv c/d/e d/e &&
	shit commit -m "c/d/e -> d/e" &&
	shit diff -M --summary HEAD^ HEAD >output &&
	test_grep " {c/d => d}/e " output &&
	shit diff -M --stat HEAD^ HEAD >output &&
	test_grep " {c/d => d}/e " output
'

test_expect_success 'rename pretty print with common prefix and suffix' '
	mkdir d/f &&
	shit mv d/e d/f/e &&
	shit commit -m "d/e -> d/f/e" &&
	shit diff -M --summary HEAD^ HEAD >output &&
	test_grep " d/{ => f}/e " output &&
	shit diff -M --stat HEAD^ HEAD >output &&
	test_grep " d/{ => f}/e " output
'

test_expect_success 'rename pretty print common prefix and suffix overlap' '
	mkdir d/f/f &&
	shit mv d/f/e d/f/f/e &&
	shit commit -m "d/f/e d/f/f/e" &&
	shit diff -M --summary HEAD^ HEAD >output &&
	test_grep " d/f/{ => f}/e " output &&
	shit diff -M --stat HEAD^ HEAD >output &&
	test_grep " d/f/{ => f}/e " output
'

test_expect_success 'diff-tree -l0 defaults to a big rename limit, not zero' '
	test_write_lines line1 line2 line3 >myfile &&
	shit add myfile &&
	shit commit -m x &&

	test_write_lines line1 line2 line4 >myotherfile &&
	shit rm myfile &&
	shit add myotherfile &&
	shit commit -m x &&

	shit diff-tree -M -l0 HEAD HEAD^ >actual &&
	# Verify that a rename from myotherfile to myfile was detected
	grep "myotherfile.*myfile" actual
'

test_expect_success 'basename similarity vs best similarity' '
	mkdir subdir &&
	test_write_lines line1 line2 line3 line4 line5 \
			 line6 line7 line8 line9 line10 >subdir/file.txt &&
	shit add subdir/file.txt &&
	shit commit -m "base txt" &&

	shit rm subdir/file.txt &&
	test_write_lines line1 line2 line3 line4 line5 \
			  line6 line7 line8 >file.txt &&
	test_write_lines line1 line2 line3 line4 line5 \
			  line6 line7 line8 line9 >file.md &&
	shit add file.txt file.md &&
	shit commit -a -m "rename" &&
	shit diff-tree -r -M --name-status HEAD^ HEAD >actual &&
	# subdir/file.txt is 88% similar to file.md, 78% similar to file.txt,
	# but since same basenames are checked first...
	cat >expected <<-\EOF &&
	A	file.md
	R078	subdir/file.txt	file.txt
	EOF
	test_cmp expected actual
'

test_expect_success 'last line matters too' '
	{
		test_write_lines a 0 1 2 3 4 5 6 7 8 9 &&
		printf "shit ignores final up to 63 characters if not newline terminated"
	} >no-final-lf &&
	shit add no-final-lf &&
	shit commit -m "original version of file with no final newline" &&

	# Change ONLY the first character of the whole file
	{
		test_write_lines b 0 1 2 3 4 5 6 7 8 9 &&
		printf "shit ignores final up to 63 characters if not newline terminated"
	} >no-final-lf &&
	shit add no-final-lf &&
	shit mv no-final-lf still-absent-final-lf &&
	shit commit -a -m "rename no-final-lf -> still-absent-final-lf" &&
	shit diff-tree -r -M --name-status HEAD^ HEAD >actual &&
	sed -e "s/^R[0-9]*	/R	/" actual >actual.munged &&
	cat >expected <<-\EOF &&
	R	no-final-lf	still-absent-final-lf
	EOF
	test_cmp expected actual.munged
'

test_done
