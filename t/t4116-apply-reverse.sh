#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit apply in reverse

'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	test_write_lines a b c d e f g h i j k l m n >file1 &&
	perl -pe "y/ijk/\\000\\001\\002/" <file1 >file2 &&

	shit add file1 file2 &&
	shit commit -m initial &&
	shit tag initial &&

	test_write_lines a b c g h i J K L m o n p q >file1 &&
	perl -pe "y/mon/\\000\\001\\002/" <file1 >file2 &&

	shit commit -a -m second &&
	shit tag second &&

	shit diff --binary initial second >patch

'

test_expect_success 'apply in forward' '

	T0=$(shit rev-parse "second^{tree}") &&
	shit reset --hard initial &&
	shit apply --index --binary patch &&
	T1=$(shit write-tree) &&
	test "$T0" = "$T1"
'

test_expect_success 'apply in reverse' '

	shit reset --hard second &&
	shit apply --reverse --binary --index patch &&
	shit diff >diff &&
	test_must_be_empty diff

'

test_expect_success 'setup separate repository lacking postimage' '

	shit archive --format=tar --prefix=initial/ initial | $TAR xf - &&
	(
		cd initial && shit init && shit add .
	) &&

	shit archive --format=tar --prefix=second/ second | $TAR xf - &&
	(
		cd second && shit init && shit add .
	)

'

test_expect_success 'apply in forward without postimage' '

	T0=$(shit rev-parse "second^{tree}") &&
	(
		cd initial &&
		shit apply --index --binary ../patch &&
		T1=$(shit write-tree) &&
		test "$T0" = "$T1"
	)
'

test_expect_success 'apply in reverse without postimage' '

	T0=$(shit rev-parse "initial^{tree}") &&
	(
		cd second &&
		shit apply --index --binary --reverse ../patch &&
		T1=$(shit write-tree) &&
		test "$T0" = "$T1"
	)
'

test_expect_success 'reversing a whitespace introduction' '
	sed "s/a/a /" < file1 > file1.new &&
	mv file1.new file1 &&
	shit diff | shit apply --reverse --whitespace=error
'

test_done
