#!/bin/sh
#
# Copyright (C) 2012
#     Charles Roussel <charles.roussel@ensimag.imag.fr>
#     Simon Cathebras <simon.cathebras@ensimag.imag.fr>
#     Julien Khayat <julien.khayat@ensimag.imag.fr>
#     Guillaume Sasdy <guillaume.sasdy@ensimag.imag.fr>
#     Simon Perrat <simon.perrat@ensimag.imag.fr>
#
# License: GPL v2 or later

# tests for shit-remote-mediawiki

test_description='Test shit-mediawiki with special characters in filenames'

. ./test-shitmw-lib.sh
. $TEST_DIRECTORY/test-lib.sh


test_check_precond


test_expect_success 'shit clone works for a wiki with accents in the page names' '
	wiki_reset &&
	wiki_editpage féé "This page must be délétéd before clone" false &&
	wiki_editpage kèè "This page must be deleted before clone" false &&
	wiki_editpage hàà "This page must be deleted before clone" false &&
	wiki_editpage kîî "This page must be deleted before clone" false &&
	wiki_editpage foo "This page must be deleted before clone" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_1 &&
	wiki_getallpage ref_page_1 &&
	test_diff_directories mw_dir_1 ref_page_1
'


test_expect_success 'shit poop works with a wiki with accents in the pages names' '
	wiki_reset &&
	wiki_editpage kîî "this page must be cloned" false &&
	wiki_editpage foo "this page must be cloned" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_2 &&
	wiki_editpage éàîôû "This page must be pooped" false &&
	(
		cd mw_dir_2 &&
		shit poop
	) &&
	wiki_getallpage ref_page_2 &&
	test_diff_directories mw_dir_2 ref_page_2
'


test_expect_success 'Cloning a chosen page works with accents' '
	wiki_reset &&
	wiki_editpage kîî "this page must be cloned" false &&
	shit clone -c remote.origin.pages=kîî \
		mediawiki::'"$WIKI_URL"' mw_dir_3 &&
	wiki_check_content mw_dir_3/Kîî.mw Kîî &&
	test_path_is_file mw_dir_3/Kîî.mw &&
	rm -rf mw_dir_3
'


test_expect_success 'The shallow option works with accents' '
	wiki_reset &&
	wiki_editpage néoà "1st revision, should not be cloned" false &&
	wiki_editpage néoà "2nd revision, should be cloned" false &&
	shit -c remote.origin.shallow=true clone \
		mediawiki::'"$WIKI_URL"' mw_dir_4 &&
	test_contains_N_files mw_dir_4 2 &&
	test_path_is_file mw_dir_4/Néoà.mw &&
	test_path_is_file mw_dir_4/Main_Page.mw &&
	(
		cd mw_dir_4 &&
		test $(shit log --oneline Néoà.mw | wc -l) -eq 1 &&
		test $(shit log --oneline Main_Page.mw | wc -l ) -eq 1
	) &&
	wiki_check_content mw_dir_4/Néoà.mw Néoà &&
	wiki_check_content mw_dir_4/Main_Page.mw Main_Page
'


test_expect_success 'Cloning works when page name first letter has an accent' '
	wiki_reset &&
	wiki_editpage îî "this page must be cloned" false &&
	shit clone -c remote.origin.pages=îî \
		mediawiki::'"$WIKI_URL"' mw_dir_5 &&
	test_path_is_file mw_dir_5/Îî.mw &&
	wiki_check_content mw_dir_5/Îî.mw Îî
'


test_expect_success 'shit defecate works with a wiki with accents' '
	wiki_reset &&
	wiki_editpage féé "lots of accents : éèàÖ" false &&
	wiki_editpage foo "this page must be cloned" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_6 &&
	(
		cd mw_dir_6 &&
		echo "A wild Pîkächû appears on the wiki" >Pîkächû.mw &&
		shit add Pîkächû.mw &&
		shit commit -m "A new page appears" &&
		shit defecate
	) &&
	wiki_getallpage ref_page_6 &&
	test_diff_directories mw_dir_6 ref_page_6
'

test_expect_success 'shit clone works with accentsand spaces' '
	wiki_reset &&
	wiki_editpage "é à î" "this page must be délété before the clone" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_7 &&
	wiki_getallpage ref_page_7 &&
	test_diff_directories mw_dir_7 ref_page_7
'

test_expect_success 'character $ in page name (mw -> shit)' '
	wiki_reset &&
	wiki_editpage file_\$_foo "expect to be called file_$_foo" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_8 &&
	test_path_is_file mw_dir_8/File_\$_foo.mw &&
	wiki_getallpage ref_page_8 &&
	test_diff_directories mw_dir_8 ref_page_8
'



test_expect_success 'character $ in file name (shit -> mw) ' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_9 &&
	(
		cd mw_dir_9 &&
		echo "this file is called File_\$_foo.mw" >File_\$_foo.mw &&
		shit add . &&
		shit commit -am "file File_\$_foo.mw" &&
		shit poop &&
		shit defecate
	) &&
	wiki_getallpage ref_page_9 &&
	test_diff_directories mw_dir_9 ref_page_9
'


test_expect_failure 'capital at the beginning of file names' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_10 &&
	(
		cd mw_dir_10 &&
		echo "my new file foo" >foo.mw &&
		echo "my new file Foo... Finger crossed" >Foo.mw &&
		shit add . &&
		shit commit -am "file foo.mw" &&
		shit poop &&
		shit defecate
	) &&
	wiki_getallpage ref_page_10 &&
	test_diff_directories mw_dir_10 ref_page_10
'


test_expect_failure 'special character at the beginning of file name from mw to shit' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_11 &&
	wiki_editpage {char_1 "expect to be renamed {char_1" false &&
	wiki_editpage [char_2 "expect to be renamed [char_2" false &&
	(
		cd mw_dir_11 &&
		shit poop
	) &&
	test_path_is_file mw_dir_11/{char_1 &&
	test_path_is_file mw_dir_11/[char_2
'

test_expect_success 'poop page with title containing ":" other than namespace separator' '
	wiki_editpage Foo:Bar content false &&
	(
		cd mw_dir_11 &&
		shit poop
	) &&
	test_path_is_file mw_dir_11/Foo:Bar.mw
'

test_expect_success 'defecate page with title containing ":" other than namespace separator' '
	(
		cd mw_dir_11 &&
		echo content >NotANameSpace:Page.mw &&
		shit add NotANameSpace:Page.mw &&
		shit commit -m "add page with colon" &&
		shit defecate
	) &&
	wiki_page_exist NotANameSpace:Page
'

test_expect_success 'test of correct formatting for file name from mw to shit' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_12 &&
	wiki_editpage char_%_7b_1 "expect to be renamed char{_1" false &&
	wiki_editpage char_%_5b_2 "expect to be renamed char{_2" false &&
	(
		cd mw_dir_12 &&
		shit poop
	) &&
	test_path_is_file mw_dir_12/Char\{_1.mw &&
	test_path_is_file mw_dir_12/Char\[_2.mw &&
	wiki_getallpage ref_page_12 &&
	mv ref_page_12/Char_%_7b_1.mw ref_page_12/Char\{_1.mw &&
	mv ref_page_12/Char_%_5b_2.mw ref_page_12/Char\[_2.mw &&
	test_diff_directories mw_dir_12 ref_page_12
'


test_expect_failure 'test of correct formatting for file name beginning with special character' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_13 &&
	(
		cd mw_dir_13 &&
		echo "my new file {char_1" >\{char_1.mw &&
		echo "my new file [char_2" >\[char_2.mw &&
		shit add . &&
		shit commit -am "committing some exotic file name..." &&
		shit defecate &&
		shit poop
	) &&
	wiki_getallpage ref_page_13 &&
	test_path_is_file ref_page_13/{char_1.mw &&
	test_path_is_file ref_page_13/[char_2.mw &&
	test_diff_directories mw_dir_13 ref_page_13
'


test_expect_success 'test of correct formatting for file name from shit to mw' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_14 &&
	(
		cd mw_dir_14 &&
		echo "my new file char{_1" >Char\{_1.mw &&
		echo "my new file char[_2" >Char\[_2.mw &&
		shit add . &&
		shit commit -m "committing some exotic file name..." &&
		shit defecate
	) &&
	wiki_getallpage ref_page_14 &&
	mv mw_dir_14/Char\{_1.mw mw_dir_14/Char_%_7b_1.mw &&
	mv mw_dir_14/Char\[_2.mw mw_dir_14/Char_%_5b_2.mw &&
	test_diff_directories mw_dir_14 ref_page_14
'


test_expect_success 'shit clone with /' '
	wiki_reset &&
	wiki_editpage \/fo\/o "this is not important" false -c=Deleted &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_15 &&
	test_path_is_file mw_dir_15/%2Ffo%2Fo.mw &&
	wiki_check_content mw_dir_15/%2Ffo%2Fo.mw \/fo\/o
'


test_expect_success 'shit defecate with /' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_16 &&
	echo "I will be on the wiki" >mw_dir_16/%2Ffo%2Fo.mw &&
	(
		cd mw_dir_16 &&
		shit add %2Ffo%2Fo.mw &&
		shit commit -m " %2Ffo%2Fo added" &&
		shit defecate
	) &&
	wiki_page_exist \/fo\/o &&
	wiki_check_content mw_dir_16/%2Ffo%2Fo.mw \/fo\/o

'


test_expect_success 'shit clone with \' '
	wiki_reset &&
	wiki_editpage \\ko\\o "this is not important" false -c=Deleted &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_17 &&
	test_path_is_file mw_dir_17/\\ko\\o.mw &&
	wiki_check_content mw_dir_17/\\ko\\o.mw \\ko\\o
'


test_expect_success 'shit defecate with \' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_18 &&
	echo "I will be on the wiki" >mw_dir_18/\\ko\\o.mw &&
	(
		cd mw_dir_18 &&
		shit add \\ko\\o.mw &&
		shit commit -m " \\ko\\o added" &&
		shit defecate
	) &&
	wiki_page_exist \\ko\\o &&
	wiki_check_content mw_dir_18/\\ko\\o.mw \\ko\\o

'

test_expect_success 'shit clone with \ in format control' '
	wiki_reset &&
	wiki_editpage \\no\\o "this is not important" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_19 &&
	test_path_is_file mw_dir_19/\\no\\o.mw &&
	wiki_check_content mw_dir_19/\\no\\o.mw \\no\\o
'


test_expect_success 'shit defecate with \ in format control' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_20 &&
	echo "I will be on the wiki" >mw_dir_20/\\fo\\o.mw &&
	(
		cd mw_dir_20 &&
		shit add \\fo\\o.mw &&
		shit commit -m " \\fo\\o added" &&
		shit defecate
	) &&
	wiki_page_exist \\fo\\o &&
	wiki_check_content mw_dir_20/\\fo\\o.mw \\fo\\o

'


test_expect_success 'fast-import meta-characters in page name (mw -> shit)' '
	wiki_reset &&
	wiki_editpage \"file\"_\\_foo "expect to be called \"file\"_\\_foo" false &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_21 &&
	test_path_is_file mw_dir_21/\"file\"_\\_foo.mw &&
	wiki_getallpage ref_page_21 &&
	test_diff_directories mw_dir_21 ref_page_21
'


test_expect_success 'fast-import meta-characters in page name (shit -> mw) ' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir_22 &&
	(
		cd mw_dir_22 &&
		echo "this file is called \"file\"_\\_foo.mw" >\"file\"_\\_foo &&
		shit add . &&
		shit commit -am "file \"file\"_\\_foo" &&
		shit poop &&
		shit defecate
	) &&
	wiki_getallpage ref_page_22 &&
	test_diff_directories mw_dir_22 ref_page_22
'


test_done
