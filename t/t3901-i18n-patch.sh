#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='i18n settings and format-patch | am pipe'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_encoding () {
	# Make sure characters are not corrupted
	cnt="$1" header="$2" i=1 j=0
	while test "$i" -le $cnt
	do
		shit format-patch --encoding=UTF-8 --stdout HEAD~$i..HEAD~$j |
		grep "^From: =?UTF-8?q?=C3=81=C3=A9=C3=AD=20=C3=B3=C3=BA?=" &&
		shit cat-file commit HEAD~$j |
		case "$header" in
		8859)
			grep "^encoding ISO8859-1" ;;
		*)
			grep "^encoding ISO8859-1"; test "$?" != 0 ;;
		esac || return 1
		j=$i
		i=$(($i+1))
	done
}

test_expect_success setup '
	shit config i18n.commitencoding UTF-8 &&

	# use UTF-8 in author and committer name to match the
	# i18n.commitencoding settings
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	test_tick &&
	echo "$shit_AUTHOR_NAME" >mine &&
	shit add mine &&
	shit commit -s -m "Initial commit" &&

	test_tick &&
	echo Hello world >mine &&
	shit add mine &&
	shit commit -s -m "Second on main" &&

	# the first commit on the side branch is UTF-8
	test_tick &&
	shit checkout -b side main^ &&
	echo Another file >yours &&
	shit add yours &&
	shit commit -s -m "Second on side" &&

	if test_have_prereq !MINGW
	then
		# the second one on the side branch is ISO-8859-1
		shit config i18n.commitencoding ISO8859-1 &&
		# use author and committer name in ISO-8859-1 to match it.
		. "$TEST_DIRECTORY"/t3901/8859-1.txt
	fi &&
	test_tick &&
	echo Yet another >theirs &&
	shit add theirs &&
	shit commit -s -m "Third on side" &&

	# Back to default
	shit config i18n.commitencoding UTF-8
'

test_expect_success 'format-patch output (ISO-8859-1)' '
	shit config i18n.logoutputencoding ISO8859-1 &&

	shit format-patch --stdout main..HEAD^ >out-l1 &&
	shit format-patch --stdout HEAD^ >out-l2 &&
	grep "^Content-Type: text/plain; charset=ISO8859-1" out-l1 &&
	grep "^From: =?ISO8859-1?q?=C1=E9=ED=20=F3=FA?=" out-l1 &&
	grep "^Content-Type: text/plain; charset=ISO8859-1" out-l2 &&
	grep "^From: =?ISO8859-1?q?=C1=E9=ED=20=F3=FA?=" out-l2
'

test_expect_success 'format-patch output (UTF-8)' '
	shit config i18n.logoutputencoding UTF-8 &&

	shit format-patch --stdout main..HEAD^ >out-u1 &&
	shit format-patch --stdout HEAD^ >out-u2 &&
	grep "^Content-Type: text/plain; charset=UTF-8" out-u1 &&
	grep "^From: =?UTF-8?q?=C3=81=C3=A9=C3=AD=20=C3=B3=C3=BA?=" out-u1 &&
	grep "^Content-Type: text/plain; charset=UTF-8" out-u2 &&
	grep "^From: =?UTF-8?q?=C3=81=C3=A9=C3=AD=20=C3=B3=C3=BA?=" out-u2
'

test_expect_success 'rebase (U/U)' '
	# We want the result of rebase in UTF-8
	shit config i18n.commitencoding UTF-8 &&

	# The test is about logoutputencoding not affecting the
	# final outcome -- it is used internally to generate the
	# patch and the log.

	shit config i18n.logoutputencoding UTF-8 &&

	# The result will be committed by shit_COMMITTER_NAME --
	# we want UTF-8 encoded name.
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&
	shit checkout -b test &&
	shit rebase main &&

	check_encoding 2
'

test_expect_success 'rebase (U/L)' '
	shit config i18n.commitencoding UTF-8 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard side &&
	shit rebase main &&

	check_encoding 2
'

test_expect_success !MINGW 'rebase (L/L)' '
	# In this test we want ISO-8859-1 encoded commits as the result
	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard side &&
	shit rebase main &&

	check_encoding 2 8859
'

test_expect_success !MINGW 'rebase (L/U)' '
	# This is pathological -- use UTF-8 as intermediate form
	# to get ISO-8859-1 results.
	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard side &&
	shit rebase main &&

	check_encoding 2 8859
'

test_expect_success 'cherry-pick(U/U)' '
	# Both the commitencoding and logoutputencoding is set to UTF-8.

	shit config i18n.commitencoding UTF-8 &&
	shit config i18n.logoutputencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard main &&
	shit cherry-pick side^ &&
	shit cherry-pick side &&
	shit revert HEAD &&

	check_encoding 3
'

test_expect_success !MINGW 'cherry-pick(L/L)' '
	# Both the commitencoding and logoutputencoding is set to ISO-8859-1

	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard main &&
	shit cherry-pick side^ &&
	shit cherry-pick side &&
	shit revert HEAD &&

	check_encoding 3 8859
'

test_expect_success 'cherry-pick(U/L)' '
	# Commitencoding is set to UTF-8 but logoutputencoding is ISO-8859-1

	shit config i18n.commitencoding UTF-8 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard main &&
	shit cherry-pick side^ &&
	shit cherry-pick side &&
	shit revert HEAD &&

	check_encoding 3
'

test_expect_success !MINGW 'cherry-pick(L/U)' '
	# Again, the commitencoding is set to ISO-8859-1 but
	# logoutputencoding is set to UTF-8.

	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard main &&
	shit cherry-pick side^ &&
	shit cherry-pick side &&
	shit revert HEAD &&

	check_encoding 3 8859
'

test_expect_success 'rebase --merge (U/U)' '
	shit config i18n.commitencoding UTF-8 &&
	shit config i18n.logoutputencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard side &&
	shit rebase --merge main &&

	check_encoding 2
'

test_expect_success 'rebase --merge (U/L)' '
	shit config i18n.commitencoding UTF-8 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard side &&
	shit rebase --merge main &&

	check_encoding 2
'

test_expect_success 'rebase --merge (L/L)' '
	# In this test we want ISO-8859-1 encoded commits as the result
	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard side &&
	shit rebase --merge main &&

	check_encoding 2 8859
'

test_expect_success 'rebase --merge (L/U)' '
	# This is pathological -- use UTF-8 as intermediate form
	# to get ISO-8859-1 results.
	shit config i18n.commitencoding ISO8859-1 &&
	shit config i18n.logoutputencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard side &&
	shit rebase --merge main &&

	check_encoding 2 8859
'

test_expect_success 'am (U/U)' '
	# Apply UTF-8 patches with UTF-8 commitencoding
	shit config i18n.commitencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard main &&
	shit am out-u1 out-u2 &&

	check_encoding 2
'

test_expect_success !MINGW 'am (L/L)' '
	# Apply ISO-8859-1 patches with ISO-8859-1 commitencoding
	shit config i18n.commitencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard main &&
	shit am out-l1 out-l2 &&

	check_encoding 2 8859
'

test_expect_success 'am (U/L)' '
	# Apply ISO-8859-1 patches with UTF-8 commitencoding
	shit config i18n.commitencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&
	shit reset --hard main &&

	# am specifies --utf8 by default.
	shit am out-l1 out-l2 &&

	check_encoding 2
'

test_expect_success 'am --no-utf8 (U/L)' '
	# Apply ISO-8859-1 patches with UTF-8 commitencoding
	shit config i18n.commitencoding UTF-8 &&
	. "$TEST_DIRECTORY"/t3901/utf8.txt &&

	shit reset --hard main &&
	shit am --no-utf8 out-l1 out-l2 2>err &&

	# commit-tree will warn that the commit message does not contain valid UTF-8
	# as mailinfo did not convert it
	test_grep "did not conform" err &&

	check_encoding 2
'

test_expect_success !MINGW 'am (L/U)' '
	# Apply UTF-8 patches with ISO-8859-1 commitencoding
	shit config i18n.commitencoding ISO8859-1 &&
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&

	shit reset --hard main &&
	# mailinfo will re-code the commit message to the charset specified by
	# i18n.commitencoding
	shit am out-u1 out-u2 &&

	check_encoding 2 8859
'

test_done
