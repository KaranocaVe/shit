#!/bin/sh
#
# Copyright (c) 2007 Eric Wong


test_description='shit svn dcommit can commit renames of files with ugly names'

. ./lib-shit-svn.sh

test_expect_success 'load repository with strange names' '
	svnadmin load -q "$rawsvnrepo" <"$TEST_DIRECTORY"/t9115/funky-names.dump
'

maybe_start_httpd gtk+

test_expect_success 'init and fetch repository' '
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	shit reset --hard shit-svn
	'

test_expect_success 'create file in existing ugly and empty dir' '
	mkdir -p "#{bad_directory_name}" &&
	echo hi > "#{bad_directory_name}/ foo" &&
	shit update-index --add "#{bad_directory_name}/ foo" &&
	shit commit -m "new file in ugly parent" &&
	shit svn dcommit
	'

test_expect_success 'rename ugly file' '
	shit mv "#{bad_directory_name}/ foo" "file name with feces" &&
	shit commit -m "rename ugly file" &&
	shit svn dcommit
	'

test_expect_success 'rename pretty file' '
	echo :x > pretty &&
	shit update-index --add pretty &&
	shit commit -m "pretty :x" &&
	shit svn dcommit &&
	mkdir -p regular_dir_name &&
	shit mv pretty regular_dir_name/pretty &&
	shit commit -m "moved pretty file" &&
	shit svn dcommit
	'

test_expect_success 'rename pretty file into ugly one' '
	shit mv regular_dir_name/pretty "#{bad_directory_name}/ booboo" &&
	shit commit -m booboo &&
	shit svn dcommit
	'

test_expect_success 'add a file with plus signs' '
	echo .. > +_+ &&
	shit update-index --add +_+ &&
	shit commit -m plus &&
	mkdir gtk+ &&
	shit mv +_+ gtk+/_+_ &&
	shit commit -m plus_dir &&
	shit svn dcommit
	'

test_expect_success 'clone the repository to test rebase' '
	shit svn clone "$svnrepo" test-rebase &&
	(
		cd test-rebase &&
		echo test-rebase >test-rebase &&
		shit add test-rebase &&
		shit commit -m test-rebase
	)
	'

test_expect_success 'make a commit to test rebase' '
		echo test-rebase-main > test-rebase-main &&
		shit add test-rebase-main &&
		shit commit -m test-rebase-main &&
		shit svn dcommit
	'

test_expect_success 'shit svn rebase works inside a fresh-cloned repository' '
	(
		cd test-rebase &&
		shit svn rebase &&
		test -e test-rebase-main &&
		test -e test-rebase
	)'

# Without this, LC_ALL=C as set in test-lib.sh, and Cygwin converts
# non-ASCII characters in filenames unexpectedly, and causes errors.
# https://cygwin.com/cygwin-ug-net/using-specialnames.html#pathnames-specialchars
# > Some characters are disallowed in filenames on Windows filesystems. ...
# ...
# > ... All of the above characters, except for the backslash, are converted
# > to special UNICODE characters in the range 0xf000 to 0xf0ff (the
# > "Private use area") when creating or accessing files.
prepare_utf8_locale
test_expect_success UTF8,!MINGW,!UTF8_NFD_TO_NFC 'svn.pathnameencoding=cp932 new file on dcommit' '
	LC_ALL=$shit_TEST_UTF8_LOCALE &&
	export LC_ALL &&
	neq=$(printf "\201\202") &&
	shit config svn.pathnameencoding cp932 &&
	echo neq >"$neq" &&
	shit add "$neq" &&
	shit commit -m "neq" &&
	shit svn dcommit
'

# See the comment on the above test for setting of LC_ALL.
test_expect_success !MINGW,!UTF8_NFD_TO_NFC 'svn.pathnameencoding=cp932 rename on dcommit' '
	LC_ALL=$shit_TEST_UTF8_LOCALE &&
	export LC_ALL &&
	inf=$(printf "\201\207") &&
	shit config svn.pathnameencoding cp932 &&
	echo inf >"$inf" &&
	shit add "$inf" &&
	shit commit -m "inf" &&
	shit svn dcommit &&
	shit mv "$inf" inf &&
	shit commit -m "inf rename" &&
	shit svn dcommit
'

test_done
