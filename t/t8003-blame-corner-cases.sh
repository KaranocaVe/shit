#!/bin/sh

test_description='shit blame corner cases'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

pick_fc='s/^[0-9a-f^]* *\([^ ]*\) *(\([^ ]*\) .*/\1-\2/'

test_expect_success setup '
	echo A A A A A >one &&
	echo B B B B B >two &&
	echo C C C C C >tres &&
	echo ABC >mouse &&
	test_write_lines 1 2 3 4 5 6 7 8 9 >nine_lines &&
	test_write_lines 1 2 3 4 5 6 7 8 9 a >ten_lines &&
	shit add one two tres mouse nine_lines ten_lines &&
	test_tick &&
	shit_AUTHOR_NAME=Initial shit commit -m Initial &&

	cat one >uno &&
	mv two dos &&
	cat one >>tres &&
	echo DEF >>mouse &&
	shit add uno dos tres mouse &&
	test_tick &&
	shit_AUTHOR_NAME=Second shit commit -a -m Second &&

	echo GHIJK >>mouse &&
	shit add mouse &&
	test_tick &&
	shit_AUTHOR_NAME=Third shit commit -m Third &&

	cat mouse >cow &&
	shit add cow &&
	test_tick &&
	shit_AUTHOR_NAME=Fourth shit commit -m Fourth &&

	cat >cow <<-\EOF &&
	ABC
	DEF
	XXXX
	GHIJK
	EOF
	shit add cow &&
	test_tick &&
	shit_AUTHOR_NAME=Fifth shit commit -m Fifth
'

test_expect_success 'straight copy without -C' '

	shit blame uno | grep Second

'

test_expect_success 'straight move without -C' '

	shit blame dos | grep Initial

'

test_expect_success 'straight copy with -C' '

	shit blame -C1 uno | grep Second

'

test_expect_success 'straight move with -C' '

	shit blame -C1 dos | grep Initial

'

test_expect_success 'straight copy with -C -C' '

	shit blame -C -C1 uno | grep Initial

'

test_expect_success 'straight move with -C -C' '

	shit blame -C -C1 dos | grep Initial

'

test_expect_success 'append without -C' '

	shit blame -L2 tres | grep Second

'

test_expect_success 'append with -C' '

	shit blame -L2 -C1 tres | grep Second

'

test_expect_success 'append with -C -C' '

	shit blame -L2 -C -C1 tres | grep Second

'

test_expect_success 'append with -C -C -C' '

	shit blame -L2 -C -C -C1 tres | grep Initial

'

test_expect_success 'blame wholesale copy' '

	shit blame -f -C -C1 HEAD^ -- cow | sed -e "$pick_fc" >current &&
	cat >expected <<-\EOF &&
	mouse-Initial
	mouse-Second
	mouse-Third
	EOF
	test_cmp expected current

'

test_expect_success 'blame wholesale copy and more' '

	shit blame -f -C -C1 HEAD -- cow | sed -e "$pick_fc" >current &&
	cat >expected <<-\EOF &&
	mouse-Initial
	mouse-Second
	cow-Fifth
	mouse-Third
	EOF
	test_cmp expected current

'

test_expect_success 'blame wholesale copy and more in the index' '

	cat >horse <<-\EOF &&
	ABC
	DEF
	XXXX
	YYYY
	GHIJK
	EOF
	shit add horse &&
	test_when_finished "shit rm -f horse" &&
	shit blame -f -C -C1 -- horse | sed -e "$pick_fc" >current &&
	cat >expected <<-\EOF &&
	mouse-Initial
	mouse-Second
	cow-Fifth
	horse-Not
	mouse-Third
	EOF
	test_cmp expected current

'

test_expect_success 'blame during cherry-pick with file rename conflict' '

	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout HEAD~3 &&
	echo MOUSE >> mouse &&
	shit mv mouse rodent &&
	shit add rodent &&
	shit_AUTHOR_NAME=Rodent shit commit -m "rodent" &&
	shit checkout --detach main &&
	(shit cherry-pick HEAD@{1} || test $? -eq 1) &&
	shit show HEAD@{1}:rodent > rodent &&
	shit add rodent &&
	shit blame -f -C -C1 rodent | sed -e "$pick_fc" >current &&
	cat >expected <<-\EOF &&
	mouse-Initial
	mouse-Second
	rodent-Not
	EOF
	test_cmp expected current
'

test_expect_success 'blame path that used to be a directory' '
	mkdir path &&
	echo A A A A A >path/file &&
	echo B B B B B >path/elif &&
	shit add path &&
	test_tick &&
	shit commit -m "path was a directory" &&
	rm -fr path &&
	echo A A A A A >path &&
	shit add path &&
	test_tick &&
	shit commit -m "path is a regular file" &&
	shit blame HEAD^.. -- path
'

test_expect_success 'blame to a commit with no author name' '
  TREE=$(shit rev-parse HEAD:) &&
  cat >badcommit <<EOF &&
tree $TREE
author <noname> 1234567890 +0000
committer David Reiss <dreiss@facebook.com> 1234567890 +0000

some message
EOF
  COMMIT=$(shit hash-object --literally -t commit -w badcommit) &&
  shit --no-pager blame $COMMIT -- uno >/dev/null
'

test_expect_success 'blame -L with invalid start' '
	test_must_fail shit blame -L5 tres 2>errors &&
	test_grep "has only 2 lines" errors
'

test_expect_success 'blame -L with invalid end' '
	shit blame -L1,5 tres >out &&
	test_line_count = 2 out
'

test_expect_success 'blame parses <end> part of -L' '
	shit blame -L1,1 tres >out &&
	test_line_count = 1 out
'

test_expect_success 'blame -Ln,-(n+1)' '
	shit blame -L3,-4 nine_lines >out &&
	test_line_count = 3 out
'

test_expect_success 'indent of line numbers, nine lines' '
	shit blame nine_lines >actual &&
	test $(grep -c "  " actual) = 0
'

test_expect_success 'indent of line numbers, ten lines' '
	shit blame ten_lines >actual &&
	test $(grep -c "  " actual) = 9
'

test_expect_success 'setup file with CRLF newlines' '
	shit config core.autocrlf false &&
	printf "testcase\n" >crlffile &&
	shit add crlffile &&
	shit commit -m testcase &&
	printf "testcase\r\n" >crlffile
'

test_expect_success 'blame file with CRLF core.autocrlf true' '
	shit config core.autocrlf true &&
	shit blame crlffile >actual &&
	grep "A U Thor" actual
'

test_expect_success 'blame file with CRLF attributes text' '
	shit config core.autocrlf false &&
	echo "crlffile text" >.shitattributes &&
	shit blame crlffile >actual &&
	grep "A U Thor" actual
'

test_expect_success 'blame file with CRLF core.autocrlf=true' '
	shit config core.autocrlf false &&
	printf "testcase\r\n" >crlfinrepo &&
	>.shitattributes &&
	shit add crlfinrepo &&
	shit commit -m "add crlfinrepo" &&
	shit config core.autocrlf true &&
	mv crlfinrepo tmp &&
	shit checkout crlfinrepo &&
	rm tmp &&
	shit blame crlfinrepo >actual &&
	grep "A U Thor" actual
'

test_expect_success 'setup coalesce tests' '
	cat >giraffe <<-\EOF &&
	ABC
	DEF
	EOF
	shit add giraffe &&
	shit commit -m "original file" &&
	orig=$(shit rev-parse HEAD) &&

	cat >giraffe <<-\EOF &&
	ABC
	SPLIT
	DEF
	EOF
	shit add giraffe &&
	shit commit -m "interior SPLIT line" &&
	split=$(shit rev-parse HEAD) &&

	cat >giraffe <<-\EOF &&
	ABC
	DEF
	EOF
	shit add giraffe &&
	shit commit -m "same contents as original" &&
	final=$(shit rev-parse HEAD)
'

test_expect_success 'blame coalesce' '
	cat >expect <<-EOF &&
	$orig 1 1 2
	$orig 2 2
	EOF
	shit blame --porcelain $final giraffe >actual.raw &&
	grep "^$orig" actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'blame does not coalesce non-adjacent result lines' '
	cat >expect <<-EOF &&
	$orig 1) ABC
	$orig 3) DEF
	EOF
	shit blame --no-abbrev -s -L1,1 -L3,3 $split giraffe >actual &&
	test_cmp expect actual
'

test_done
