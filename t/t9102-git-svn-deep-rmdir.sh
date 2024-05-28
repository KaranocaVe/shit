#!/bin/sh
test_description='shit svn rmdir'

. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	mkdir import &&
	(
		cd import &&
		mkdir -p deeply/nested/directory/number/1 &&
		mkdir -p deeply/nested/directory/number/2 &&
		echo foo >deeply/nested/directory/number/1/file &&
		echo foo >deeply/nested/directory/number/2/another &&
		svn_cmd import -m "import for shit svn" . "$svnrepo"
	)
	'

test_expect_success 'mirror via shit svn' '
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	shit checkout -f -b test-rmdir remotes/shit-svn
	'

test_expect_success 'Try a commit on rmdir' '
	shit rm -f deeply/nested/directory/number/2/another &&
	shit commit -a -m "remove another" &&
	shit svn set-tree --rmdir HEAD &&
	svn_cmd ls -R "$svnrepo" | grep ^deeply/nested/directory/number/1
	'


test_done
