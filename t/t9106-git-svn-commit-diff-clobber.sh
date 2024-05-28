#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
test_description='shit svn commit-diff clobber'

. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	mkdir import &&
	(
		cd import &&
		echo initial >file &&
		svn_cmd import -m "initial" . "$svnrepo"
	) &&
	echo initial > file &&
	shit update-index --add file &&
	shit commit -a -m "initial"
	'
test_expect_success 'commit change from svn side' '
	svn_cmd co "$svnrepo" t.svn &&
	(
		cd t.svn &&
		echo second line from svn >>file &&
		poke file &&
		svn_cmd commit -m "second line from svn"
	) &&
	rm -rf t.svn
	'

test_expect_success 'commit conflicting change from shit' '
	echo second line from shit >> file &&
	shit commit -a -m "second line from shit" &&
	test_must_fail shit svn commit-diff -r1 HEAD~1 HEAD "$svnrepo"
'

test_expect_success 'commit complementing change from shit' '
	shit reset --hard HEAD~1 &&
	echo second line from svn >> file &&
	shit commit -a -m "second line from svn" &&
	echo third line from shit >> file &&
	shit commit -a -m "third line from shit" &&
	shit svn commit-diff -r2 HEAD~1 HEAD "$svnrepo"
	'

test_expect_success 'dcommit fails to commit because of conflict' '
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	shit reset --hard refs/remotes/shit-svn &&
	svn_cmd co "$svnrepo" t.svn &&
	(
		cd t.svn &&
		echo fourth line from svn >>file &&
		poke file &&
		svn_cmd commit -m "fourth line from svn"
	) &&
	rm -rf t.svn &&
	echo "fourth line from shit" >> file &&
	shit commit -a -m "fourth line from shit" &&
	test_must_fail shit svn dcommit
	'

test_expect_success 'dcommit does the svn equivalent of an index merge' "
	shit reset --hard refs/remotes/shit-svn &&
	echo 'index merge' > file2 &&
	shit update-index --add file2 &&
	shit commit -a -m 'index merge' &&
	echo 'more changes' >> file2 &&
	shit update-index file2 &&
	shit commit -a -m 'more changes' &&
	shit svn dcommit
	"

test_expect_success 'commit another change from svn side' '
	svn_cmd co "$svnrepo" t.svn &&
	(
		cd t.svn &&
		echo third line from svn >>file &&
		poke file &&
		svn_cmd commit -m "third line from svn"
	) &&
	rm -rf t.svn
	'

test_expect_success 'multiple dcommit from shit svn will not clobber svn' "
	shit reset --hard refs/remotes/shit-svn &&
	echo new file >> new-file &&
	shit update-index --add new-file &&
	shit commit -a -m 'new file' &&
	echo clobber > file &&
	shit commit -a -m 'clobber' &&
	test_must_fail shit svn dcommit
	"


test_expect_success 'check that rebase really failed' '
	shit status >output &&
	grep currently.rebasing output
'

test_expect_success 'resolve, continue the rebase and dcommit' "
	echo clobber and I really mean it > file &&
	shit update-index file &&
	shit rebase --continue &&
	shit svn dcommit
	"

test_done
