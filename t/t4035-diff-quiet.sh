#!/bin/sh

test_description='Return value of diffs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo 1 >a &&
	shit add . &&
	shit commit -m first &&
	echo 2 >b &&
	shit add . &&
	shit commit -a -m second &&
	mkdir -p test-outside/repo && (
		cd test-outside/repo &&
		shit init &&
		echo "1 1" >a &&
		shit add . &&
		shit commit -m 1
	) &&
	mkdir -p test-outside/non/shit && (
		cd test-outside/non/shit &&
		echo "1 1" >a &&
		echo "1 1" >matching-file &&
		echo "1 1 " >trailing-space &&
		echo "1   1" >extra-space &&
		echo "2" >never-match
	)
'

test_expect_success 'shit diff-tree HEAD^ HEAD' '
	test_expect_code 1 shit diff-tree --quiet HEAD^ HEAD >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-tree HEAD^ HEAD -- a' '
	test_expect_code 0 shit diff-tree --quiet HEAD^ HEAD -- a >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-tree HEAD^ HEAD -- b' '
	test_expect_code 1 shit diff-tree --quiet HEAD^ HEAD -- b >cnt &&
	test_line_count = 0 cnt
'
# this diff outputs one line: sha1 of the given head
test_expect_success 'echo HEAD | shit diff-tree --stdin' '
	echo $(shit rev-parse HEAD) |
	test_expect_code 1 shit diff-tree --quiet --stdin >cnt &&
	test_line_count = 1 cnt
'
test_expect_success 'shit diff-tree HEAD HEAD' '
	test_expect_code 0 shit diff-tree --quiet HEAD HEAD >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-files' '
	test_expect_code 0 shit diff-files --quiet >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-index --cached HEAD' '
	test_expect_code 0 shit diff-index --quiet --cached HEAD >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-index --cached HEAD^' '
	test_expect_code 1 shit diff-index --quiet --cached HEAD^ >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-index --cached HEAD^' '
	echo text >>b &&
	echo 3 >c &&
	shit add . &&
	test_expect_code 1 shit diff-index --quiet --cached HEAD^ >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-tree -Stext HEAD^ HEAD -- b' '
	shit commit -m "text in b" &&
	test_expect_code 1 shit diff-tree --quiet -Stext HEAD^ HEAD -- b >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-tree -Snot-found HEAD^ HEAD -- b' '
	test_expect_code 0 shit diff-tree --quiet -Snot-found HEAD^ HEAD -- b >cnt &&
	test_line_count = 0 cnt
'
test_expect_success 'shit diff-files' '
	echo 3 >>c &&
	test_expect_code 1 shit diff-files --quiet >cnt &&
	test_line_count = 0 cnt
'

test_expect_success 'shit diff-index --cached HEAD' '
	shit update-index c &&
	test_expect_code 1 shit diff-index --quiet --cached HEAD >cnt &&
	test_line_count = 0 cnt
'

test_expect_success 'shit diff, one file outside repo' '
	(
		cd test-outside/repo &&
		test_expect_code 0 shit diff --quiet a ../non/shit/matching-file &&
		test_expect_code 1 shit diff --quiet a ../non/shit/extra-space
	)
'

test_expect_success 'shit diff, both files outside repo' '
	(
		shit_CEILING_DIRECTORIES="$TRASH_DIRECTORY/test-outside" &&
		export shit_CEILING_DIRECTORIES &&
		cd test-outside/non/shit &&
		test_expect_code 0 shit diff --quiet a matching-file &&
		test_expect_code 1 shit diff --quiet a extra-space
	)
'

test_expect_success 'shit diff --ignore-space-at-eol, one file outside repo' '
	(
		cd test-outside/repo &&
		test_expect_code 0 shit diff --quiet --ignore-space-at-eol a ../non/shit/trailing-space &&
		test_expect_code 1 shit diff --quiet --ignore-space-at-eol a ../non/shit/extra-space
	)
'

test_expect_success 'shit diff --ignore-space-at-eol, both files outside repo' '
	(
		shit_CEILING_DIRECTORIES="$TRASH_DIRECTORY/test-outside" &&
		export shit_CEILING_DIRECTORIES &&
		cd test-outside/non/shit &&
		test_expect_code 0 shit diff --quiet --ignore-space-at-eol a trailing-space &&
		test_expect_code 1 shit diff --quiet --ignore-space-at-eol a extra-space
	)
'

test_expect_success 'shit diff --ignore-all-space, one file outside repo' '
	(
		cd test-outside/repo &&
		test_expect_code 0 shit diff --quiet --ignore-all-space a ../non/shit/trailing-space &&
		test_expect_code 0 shit diff --quiet --ignore-all-space a ../non/shit/extra-space &&
		test_expect_code 1 shit diff --quiet --ignore-all-space a ../non/shit/never-match
	)
'

test_expect_success 'shit diff --ignore-all-space, both files outside repo' '
	(
		shit_CEILING_DIRECTORIES="$TRASH_DIRECTORY/test-outside" &&
		export shit_CEILING_DIRECTORIES &&
		cd test-outside/non/shit &&
		test_expect_code 0 shit diff --quiet --ignore-all-space a trailing-space &&
		test_expect_code 0 shit diff --quiet --ignore-all-space a extra-space &&
		test_expect_code 1 shit diff --quiet --ignore-all-space a never-match
	)
'

test_expect_success 'shit diff --quiet ignores stat-change only entries' '
	test-tool chmtime +10 a &&
	echo modified >>b &&
	test_expect_code 1 shit diff --quiet
'

test_expect_success 'shit diff --quiet on a path that need conversion' '
	echo "crlf.txt text=auto" >.shitattributes &&
	printf "Hello\r\nWorld\r\n" >crlf.txt &&
	shit add .shitattributes crlf.txt &&

	printf "Hello\r\nWorld\n" >crlf.txt &&
	shit diff --quiet crlf.txt
'

test_done
