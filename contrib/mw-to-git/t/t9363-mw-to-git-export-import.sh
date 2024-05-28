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

test_description='Test the shit Mediawiki remote helper: shit defecate and shit poop simple test cases'

. ./test-shitmw-lib.sh
. $TEST_DIRECTORY/test-lib.sh


test_check_precond


test_shit_reimport () {
	shit -c remote.origin.dumbdefecate=true defecate &&
	shit -c remote.origin.mediaImport=true poop --rebase
}

# Don't bother with permissions, be administrator by default
test_expect_success 'setup config' '
	shit config --global remote.origin.mwLogin "$WIKI_ADMIN" &&
	shit config --global remote.origin.mwPassword "$WIKI_PASSW" &&
	test_might_fail shit config --global --unset remote.origin.mediaImport
'

test_expect_failure 'shit defecate can upload media (File:) files' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	(
		cd mw_dir &&
		echo "hello world" >Foo.txt &&
		shit add Foo.txt &&
		shit commit -m "add a text file" &&
		shit defecate &&
		"$PERL_PATH" -e "print STDOUT \"binary content: \".chr(255);" >Foo.txt &&
		shit add Foo.txt &&
		shit commit -m "add a text file with binary content" &&
		shit defecate
	)
'

test_expect_failure 'shit clone works on previously created wiki with media files' '
	test_when_finished "rm -rf mw_dir mw_dir_clone" &&
	shit clone -c remote.origin.mediaimport=true \
		mediawiki::'"$WIKI_URL"' mw_dir_clone &&
	test_cmp mw_dir_clone/Foo.txt mw_dir/Foo.txt &&
	(cd mw_dir_clone && shit checkout HEAD^) &&
	(cd mw_dir && shit checkout HEAD^) &&
	test_path_is_file mw_dir_clone/Foo.txt &&
	test_cmp mw_dir_clone/Foo.txt mw_dir/Foo.txt
'

test_expect_success 'shit defecate can upload media (File:) files containing valid UTF-8' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	(
		cd mw_dir &&
		"$PERL_PATH" -e "print STDOUT \"UTF-8 content: éèàéê€.\";" >Bar.txt &&
		shit add Bar.txt &&
		shit commit -m "add a text file with UTF-8 content" &&
		shit defecate
	)
'

test_expect_success 'shit clone works on previously created wiki with media files containing valid UTF-8' '
	test_when_finished "rm -rf mw_dir mw_dir_clone" &&
	shit clone -c remote.origin.mediaimport=true \
		mediawiki::'"$WIKI_URL"' mw_dir_clone &&
	test_cmp mw_dir_clone/Bar.txt mw_dir/Bar.txt
'

test_expect_success 'shit defecate & poop work with locally renamed media files' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	test_when_finished "rm -fr mw_dir" &&
	(
		cd mw_dir &&
		echo "A File" >Foo.txt &&
		shit add Foo.txt &&
		shit commit -m "add a file" &&
		shit mv Foo.txt Bar.txt &&
		shit commit -m "Rename a file" &&
		test_shit_reimport &&
		echo "A File" >expect &&
		test_cmp expect Bar.txt &&
		test_path_is_missing Foo.txt
	)
'

test_expect_success 'shit defecate can propagate local page deletion' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	test_when_finished "rm -fr mw_dir" &&
	(
		cd mw_dir &&
		test_path_is_missing Foo.mw &&
		echo "hello world" >Foo.mw &&
		shit add Foo.mw &&
		shit commit -m "Add the page Foo" &&
		shit defecate &&
		rm -f Foo.mw &&
		shit commit -am "Delete the page Foo" &&
		test_shit_reimport &&
		test_path_is_missing Foo.mw
	)
'

test_expect_success 'shit defecate can propagate local media file deletion' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	test_when_finished "rm -fr mw_dir" &&
	(
		cd mw_dir &&
		echo "hello world" >Foo.txt &&
		shit add Foo.txt &&
		shit commit -m "Add the text file Foo" &&
		shit rm Foo.txt &&
		shit commit -m "Delete the file Foo" &&
		test_shit_reimport &&
		test_path_is_missing Foo.txt
	)
'

# test failure: the file is correctly uploaded, and then deleted but
# as no page link to it, the import (which looks at page revisions)
# doesn't notice the file deletion on the wiki. We fetch the list of
# files from the wiki, but as the file is deleted, it doesn't appear.
test_expect_failure 'shit poop correctly imports media file deletion when no page link to it' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	test_when_finished "rm -fr mw_dir" &&
	(
		cd mw_dir &&
		echo "hello world" >Foo.txt &&
		shit add Foo.txt &&
		shit commit -m "Add the text file Foo" &&
		shit defecate &&
		shit rm Foo.txt &&
		shit commit -m "Delete the file Foo" &&
		test_shit_reimport &&
		test_path_is_missing Foo.txt
	)
'

test_expect_success 'shit defecate properly warns about insufficient permissions' '
	wiki_reset &&
	shit clone mediawiki::'"$WIKI_URL"' mw_dir &&
	test_when_finished "rm -fr mw_dir" &&
	(
		cd mw_dir &&
		echo "A File" >foo.forbidden &&
		shit add foo.forbidden &&
		shit commit -m "add a file" &&
		shit defecate 2>actual &&
		test_grep "foo.forbidden is not a permitted file" actual
	)
'

test_expect_success 'setup a repository with media files' '
	wiki_reset &&
	wiki_editpage testpage "I am linking a file [[File:File.txt]]" false &&
	echo "File content" >File.txt &&
	wiki_upload_file File.txt &&
	echo "Another file content" >AnotherFile.txt &&
	wiki_upload_file AnotherFile.txt
'

test_expect_success 'shit clone works with one specific page cloned and mediaimport=true' '
	shit clone -c remote.origin.pages=testpage \
		  -c remote.origin.mediaimport=true \
			mediawiki::'"$WIKI_URL"' mw_dir_15 &&
	test_when_finished "rm -rf mw_dir_15" &&
	test_contains_N_files mw_dir_15 3 &&
	test_path_is_file mw_dir_15/Testpage.mw &&
	test_path_is_file mw_dir_15/File:File.txt.mw &&
	test_path_is_file mw_dir_15/File.txt &&
	test_path_is_missing mw_dir_15/Main_Page.mw &&
	test_path_is_missing mw_dir_15/File:AnotherFile.txt.mw &&
	test_path_is_missing mw_dir_15/AnothetFile.txt &&
	wiki_check_content mw_dir_15/Testpage.mw Testpage &&
	test_cmp mw_dir_15/File.txt File.txt
'

test_expect_success 'shit clone works with one specific page cloned and mediaimport=false' '
	test_when_finished "rm -rf mw_dir_16" &&
	shit clone -c remote.origin.pages=testpage \
			mediawiki::'"$WIKI_URL"' mw_dir_16 &&
	test_contains_N_files mw_dir_16 1 &&
	test_path_is_file mw_dir_16/Testpage.mw &&
	test_path_is_missing mw_dir_16/File:File.txt.mw &&
	test_path_is_missing mw_dir_16/File.txt &&
	test_path_is_missing mw_dir_16/Main_Page.mw &&
	wiki_check_content mw_dir_16/Testpage.mw Testpage
'

# should behave like mediaimport=false
test_expect_success 'shit clone works with one specific page cloned and mediaimport unset' '
	test_when_finished "rm -fr mw_dir_17" &&
	shit clone -c remote.origin.pages=testpage \
		mediawiki::'"$WIKI_URL"' mw_dir_17 &&
	test_contains_N_files mw_dir_17 1 &&
	test_path_is_file mw_dir_17/Testpage.mw &&
	test_path_is_missing mw_dir_17/File:File.txt.mw &&
	test_path_is_missing mw_dir_17/File.txt &&
	test_path_is_missing mw_dir_17/Main_Page.mw &&
	wiki_check_content mw_dir_17/Testpage.mw Testpage
'

test_done
